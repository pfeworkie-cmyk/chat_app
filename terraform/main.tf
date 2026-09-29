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

# --- VPC & NETWORKING ---
resource "aws_vpc" "chat_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "devsecops-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.chat_vpc.id
  tags   = { Name = "devsecops-igw" }
}

resource "aws_subnet" "subnet_1" {
  vpc_id                  = aws_vpc.chat_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags                    = { Name = "eks-subnet-1" }
}

resource "aws_subnet" "subnet_2" {
  vpc_id                  = aws_vpc.chat_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
  tags                    = { Name = "eks-subnet-2" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.chat_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "devsecops-public-rt" }
}

resource "aws_route_table_association" "assoc_subnet_1" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "assoc_subnet_2" {
  subnet_id      = aws_subnet.subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

# --- EKS CLUSTER & WORKER NODES ---
resource "aws_eks_cluster" "chat_cluster" {
  name     = var.cluster_name
  role_arn = var.role_arn
  version  = "1.30"

  vpc_config {
    subnet_ids              = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id]
    endpoint_public_access  = true
    endpoint_private_access = true
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
  }
}

resource "aws_eks_node_group" "chat_workers" {
  cluster_name    = aws_eks_cluster.chat_cluster.name
  node_group_name = "chat-app-workers"
  node_role_arn   = var.role_arn
  subnet_ids      = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id]

  ami_type        = "AL2_x86_64"

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.medium"]
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
