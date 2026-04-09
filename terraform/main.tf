data "aws_caller_identity" "current" {}
provider "aws" {
  region = "us-east-1"
}

# 1. Création du VPC
resource "aws_vpc" "my_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "my-eks-vpc" }
}

# 2. Création des Subnets (Indispensable pour EKS)
resource "aws_subnet" "subnet_1" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
  tags = { Name = "eks-subnet-1" }
}

resource "aws_subnet" "subnet_2" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
  tags = { Name = "eks-subnet-2" }
}

# 3. Internet Gateway pour l'accès public
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

# 4. Groupes de Sécurité (Lies dynamiquement au vpc_id)
resource "aws_security_group" "eks_cluster_sg" {
  name        = "eks-cluster-sg-mykubernetes"
  vpc_id      = aws_vpc.my_vpc.id # CORRECTION ICI

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

resource "aws_security_group" "eks_worker_sg" {
  name        = "eks-worker-sg-mykubernetes"
  vpc_id      = aws_vpc.my_vpc.id # CORRECTION ICI

  ingress {
    from_port   = 30000
    to_port     = 30000
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

# 5. Cluster EKS
resource "aws_eks_cluster" "my_cluster" {
  name     = "mykubernetes"
  role_arn = "arn:aws:iam::744983671605:role/LabRole"
  version  = "1.30"

  vpc_config {
    subnet_ids = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id] # CORRECTION ICI
    security_group_ids = [aws_security_group.eks_cluster_sg.id]
  }
}

# 6. Node Group (Les machines qui font tourner ton app)
resource "aws_eks_node_group" "my_node_group" {
  cluster_name    = aws_eks_cluster.my_cluster.name
  node_group_name = "noeud1"
  node_role_arn   = "arn:aws:iam::744983671605:role/LabRole"
  subnet_ids      = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id] # CORRECTION ICI

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }
}
