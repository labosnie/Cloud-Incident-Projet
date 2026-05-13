variable "name_prefix" {
  description = "Préfixe pour les noms des ressources réseau (ex. cloudops-incident-dev)."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR du VPC."
  type        = string
}

variable "public_subnet_cidrs" {
  description = "Liste des CIDR des subnets publics (une entrée par AZ, ordre = AZ 1, AZ 2, ...)."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Ce module attend exactement 2 subnets publics (2 AZ)."
  }
}

variable "private_subnet_cidrs" {
  description = "Liste des CIDR des subnets privés (une entrée par AZ)."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_cidrs) == 2
    error_message = "Ce module attend exactement 2 subnets privés (2 AZ)."
  }
}
