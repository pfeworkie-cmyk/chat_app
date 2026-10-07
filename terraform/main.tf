terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# --- DATA SOURCES POUR LES SOUS-RESEAUX (EXCLUANT us-east-1e) ---
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnet" "filtered" {
  for_each = toset(data.aws_subnets.default.ids)
  id       = each.value
}

locals {
  valid_subnet_ids = [
    for s in data.aws_subnet.filtered : s.id if s.availability_zone != "us-east-1e"
  ]
}

# --- CLUSTER EKS ---
resource "aws_eks_cluster" "chat_cluster" {
  name     = var.cluster_name
  role_arn = var.role_arn
  version  = "1.30"

  vpc_config {
    subnet_ids              = local.valid_subnet_ids
    endpoint_public_access  = true
    endpoint_private_access = true
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
  }
}

# --- AUTORISER LE VPC (DONC JENKINS) A JOINDRE L'API EKS SUR LE PORT 443 ---
# Sans cette regle, kubectl depuis l'instance Jenkins expire (i/o timeout)
resource "aws_security_group_rule" "vpc_to_eks_api" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_eks_cluster.chat_cluster.vpc_config[0].cluster_security_group_id
  cidr_blocks       = [data.aws_vpc.default.cidr_block]
  description       = "VPC (Jenkins) vers API EKS"
}

# --- GROUPE DE NOEUDS ---
resource "aws_eks_node_group" "chat_workers" {
  cluster_name    = aws_eks_cluster.chat_cluster.name
  node_group_name = "chat-app-workers"
  node_role_arn   = var.role_arn
  subnet_ids      = local.valid_subnet_ids

  ami_type       = "AL2_x86_64"
  instance_types = ["t3.medium"]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  depends_on = [
    aws_eks_cluster.chat_cluster,
    aws_security_group_rule.vpc_to_eks_api
  ]
}

# --- OUTPUTS ---
output "cluster_name" {
  value       = aws_eks_cluster.chat_cluster.name
  description = "Name of the EKS cluster"
}

output "cluster_endpoint" {
  value       = aws_eks_cluster.chat_cluster.endpoint
  sensitive   = true
  description = "Endpoint for EKS control plane"
}
