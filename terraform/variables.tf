variable "aws_region" {
  description = "Région AWS"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Nom du cluster EKS"
  type        = string
  default     = "my-chat-app-cluster"
}

variable "role_arn" {
  description = "ARN IAM du rôle EKS (LabRole AWS Academy)"
  type        = string
  default     = "arn:aws:iam::459638812615:role/LabRole"
}

variable "vpc_cidr" {
  description = "CIDR du VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR autorisés à joindre l’endpoint public EKS"
  type        = list(string)
  default     = ["18.232.247.183/32"]

  validation {
    condition     = length(var.cluster_endpoint_public_access_cidrs) > 0 && !contains(var.cluster_endpoint_public_access_cidrs, "0.0.0.0/0")
    error_message = "Définissez au moins un CIDR d’administration précis; 0.0.0.0/0 est interdit."
  }
}
