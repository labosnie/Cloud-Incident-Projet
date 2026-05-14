variable "name_prefix" {
  description = "Préfixe stable pour nommer cluster, services et groupes de logs (ex. cloudops-incident-dev)."
  type        = string
}

variable "vpc_id" {
  description = "ID du VPC où déployer l’ALB et les tâches ECS."
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs des subnets publics (≥ 2 AZ pour l’ALB). Les tâches Fargate y sont placées avec IP publique pour éviter un NAT Gateway."
  type        = list(string)
}

variable "container_image" {
  description = "URI complète de l’image (ex. <compte>.dkr.ecr.<région>.amazonaws.com/<repo>:tag)."
  type        = string
}

variable "container_port" {
  description = "Port d’écoute du conteneur (identique au target group)."
  type        = number
  default     = 8000
}

variable "health_check_path" {
  description = "Chemin du health check de l’ALB vers l’API."
  type        = string
  default     = "/health"
}

variable "desired_count" {
  description = "Nombre de tâches Fargate souhaité (1 minimise le coût en dev)."
  type        = number
  default     = 1

  validation {
    condition     = var.desired_count >= 0
    error_message = "desired_count doit être >= 0."
  }
}

variable "task_cpu" {
  description = "Unités CPU Fargate (256 = 0.25 vCPU)."
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Mémoire Fargate en Mo (512 avec 256 CPU est le couple minimal valide)."
  type        = number
  default     = 512
}

variable "log_retention_days" {
  description = "Rétention des logs CloudWatch (1–3 jours limite le coût en dev)."
  type        = number
  default     = 3
}

variable "assign_public_ip" {
  description = "Si true, les tâches reçoivent une IP publique pour sortir sur Internet (pull ECR, logs) sans NAT Gateway."
  type        = bool
  default     = true
}

variable "container_environment" {
  description = "Variables d’environnement injectées dans le conteneur (ex. DATABASE_URL tant que RDS n’existe pas)."
  type        = map(string)
  default     = {}
}
