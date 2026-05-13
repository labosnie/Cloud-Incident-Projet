variable "aws_region" {
  description = "Région AWS où créer le bucket et la table de verrou."
  type        = string
  default     = "eu-west-3"
}

variable "project_name" {
  description = "Nom court du projet (tags)."
  type        = string
}

variable "environment" {
  description = "Libellé pour les ressources « state » (ex. shared, bootstrap)."
  type        = string
  default     = "bootstrap"
}

variable "state_bucket_name" {
  description = "Nom du bucket S3 pour les fichiers de state Terraform (unique mondialement). Uniquement minuscules, chiffres et tirets (pas d’underscore)."
  type        = string

  validation {
    condition     = length(var.state_bucket_name) >= 3 && length(var.state_bucket_name) <= 63 && can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.state_bucket_name))
    error_message = "Le nom du bucket doit faire 3 à 63 caractères, commencer et finir par une lettre ou un chiffre, et ne contenir que des minuscules, chiffres et tirets (pas d’underscore ni de majuscules)."
  }
}

variable "lock_table_name" {
  description = "Nom de la table DynamoDB pour les verrous de state Terraform (unique par compte et région)."
  type        = string
}
