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

# --- DATA SOURCES TO AUTOMATICALLY FETCH VALID SUBNETS (EXCLUDING us-east-1e) ---
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

# --- EKS CLUSTER ---
resource "aws_eks_cluster" "chat_cluster" {
  name     = var.cluster_name
  role_arn = var.role_arn
  version  = "1.30"

  vpc_config {
    subnet_ids              = local.valid_subnet_ids
    endpoint_public_access  = true
    endpoint_private_access = false
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
  }
}

# --- LAUNCH TEMPLATE TO ASSIGN PUBLIC IPS TO WORKER NODES ---
resource "aws_launch_template" "worker_node_lt" {
  name_prefix   = "chat-worker-lt-"
  image_id      = data.aws_ssm_parameter.eks_ami.value # Optional, or let EKS use default AMI
  
  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination       = true
  }
}

# --- EKS WORKER NODE GROUP ---
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

  # Attach launch template to fix the NodeCreationFailure timeout
  launch_template {
    id      = aws_launch_template.worker_node_lt.id
    version = aws_launch_template.worker_node_lt.latest_version
  }

  depends_on = [aws_eks_cluster.chat_cluster]
}

# --- OPTIONAL: FETCH LATEST EKS OPTIMIZED AMI AUTOMATICALLY ---
data "aws_ssm_parameter" "eks_ami" {
  name = "/aws/service/eks/optimized-ami/1.30/amazon-linux-2/recommended/image_id"
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
