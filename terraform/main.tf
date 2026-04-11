provider "aws" {
  region = "us-east-1"
}

# 1. Get the current AWS Account ID (Essential for AWS LabRole)
data "aws_caller_identity" "current" {}

# 2. VPC Creation
resource "aws_vpc" "my_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "devsecops-vpc"
  }
}

# 3. Subnets (Two different Availability Zones are REQUIRED for EKS)
resource "aws_subnet" "subnet_1" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "eks-subnet-1"
  }
}

resource "aws_subnet" "subnet_2" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "eks-subnet-2"
  }
}

# 4. Internet Gateway & Routing (So your app is accessible)
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.my_vpc.id
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.subnet_2.id
  route_table_id = aws_route_table.rt.id
}

# 5. Security Groups
resource "aws_security_group" "eks_cluster_sg" {
  name   = "eks-cluster-sg-chat"
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 8083
    to_port     = 8083
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 6. EKS Cluster (Using the AWS Academy LabRole)
resource "aws_eks_cluster" "my_cluster" {
  name     = "my-chat-app-cluster" # Updated name to avoid 409 Conflict
  role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
  version  = "1.30"

  vpc_config {
    subnet_ids             = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id]
    security_group_ids     = [aws_security_group.eks_cluster_sg.id]
    endpoint_public_access = true
  }
}

# 7. Worker Node Group (The actual EC2 machines)
resource "aws_eks_node_group" "my_node_group" {
  cluster_name    = aws_eks_cluster.my_cluster.name
  node_group_name = "chat-app-workers"
  node_role_arn   = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
  subnet_ids      = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.medium"]
}

# 8. Outputs (Helpful for the Jenkins Pipeline)
output "cluster_name" {
  value = aws_eks_cluster.my_cluster.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.my_cluster.endpoint
}
