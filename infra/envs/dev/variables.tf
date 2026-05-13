variable "aws_region" {
  description = "Région AWS."
  type        = string
  default     = "eu-west-3"
}

variable "project_name" {
  description = "Nom court du projet (tag Project, préfixes)."
  type        = string
}

variable "environment" {
  description = "Nom de l'environnement (tag Environment)."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR du VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR des subnets publics (2 entrées pour 2 AZ)."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR des subnets privés (2 entrées pour 2 AZ)."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "ecr_repository_name" {
  description = "Nom du repository ECR."
  type        = string
}
