variable "aws_region" {
  description = "Région AWS"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Nom du cluster EKS"
  type        = string
  default     = "mykubernetes"
}

variable "role_arn" {
  description = "ARN IAM du rôle EKS (LabRole AWS Academy)"
  type        = string
  default     = "arn:aws:iam::749905554780:role/LabRole"
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR autorisés à joindre l'endpoint public EKS (votre PC + l'IP publique de Jenkins)"
  type        = list(string)
  # Remplacez IP_PUBLIQUE_JENKINS par le résultat de: curl ifconfig.me (sur l'instance Jenkins)
  default = ["184.194.229.118/32", "IP_PUBLIQUE_JENKINS/32"]

  validation {
    condition     = length(var.cluster_endpoint_public_access_cidrs) > 0 && !contains(var.cluster_endpoint_public_access_cidrs, "0.0.0.0/0")
    error_message = "Définissez au moins un CIDR d'administration précis; 0.0.0.0/0 est interdit."
  }
}
