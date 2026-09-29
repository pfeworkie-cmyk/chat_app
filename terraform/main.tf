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

# --- USE DEFAULT VPC INSTEAD OF CREATING ONE ---
data "aws_vpc" "default" {
  default = true
}

# --- USE DEFAULT SUBNETS IN THE REGION ---
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# --- EKS CLUSTER & WORKER NODES (Using Default Subnets) ---
resource "aws_eks_cluster" "chat_cluster" {
  name     = var.cluster_name
  role_arn = var.role_arn
  version  = "1.30"

  vpc_config {
    subnet_ids              = data.aws_subnets.default.ids
    endpoint_public_access  = true
    endpoint_private_access = true
    public_access_cidrs     = ["0.0.0.0/0"]
  }
}

resource "aws_eks_node_group" "chat_workers" {
  cluster_name    = aws_eks_cluster.chat_cluster.name
  node_group_name = "chat-app-workers"
  node_role_arn   = var.role_arn
  subnet_ids      = data.aws_subnets.default.ids

  ami_type        = "AL2_x86_64"

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.medium"]

  depends_on = [aws_eks_cluster.chat_cluster]
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
