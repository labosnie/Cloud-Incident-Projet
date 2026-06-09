variable "name_prefix" {
  description = "Prefixe stable pour nommer les ressources RDS (exemple cloudops-incident-dev)."
  type        = string
}

variable "vpc_id" {
  description = "ID du VPC."
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs des subnets privés pour le DB subnet group."
  type        = list(string)
}

variable "db_name" {
  description = "Nom de la base PostgreSQL."
  type        = string
}

variable "db_username" {
  description = "Utilisateur principal PostgreSQL."
  type        = string
}

variable "db_password" {
  description = "Mot de passe PostgreSQL (sensible, via terraform.tfvars)."
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "Classe d'instance RDS."
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Stockage alloue (Go)."
  type        = number
  default     = 20
}

variable "db_engine_version" {
  description = "Version PostgreSQL (ex. 16.6)."
  type        = string
  default     = "16.6"
}

variable "db_skip_final_snapshot" {
  description = "Si true, pas de snapshot final a la suppression (dev jetable)."
  type        = bool
  default     = true
}

variable "db_deletion_protection" {
  description = "Protection contre suppression accidentelle."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags supplementaires."
  type        = map(string)
  default     = {}
}
