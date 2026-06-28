variable "name_prefix" {
  description = "Prefixe stable pour nommer cluster, services et groupes de logs (exemple cloudops-incident-dev)."
  type        = string
}

variable "vpc_id" {
  description = "ID du VPC pour deployer le load balancer et les taches ECS."
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs des subnets publics (au moins 2 AZ pour le load balancer). Les taches Fargate y sont placees avec IP publique pour eviter un NAT Gateway."
  type        = list(string)
}

variable "container_image" {
  description = "URI complete de image Docker (exemple compte.dkr.ecr.region.amazonaws.com/referentiel:tag)."
  type        = string
}

variable "container_port" {
  description = "Port sur lequel le conteneur ecoute (identique au target group)."
  type        = number
  default     = 8000
}

variable "health_check_path" {
  description = "Chemin du health check du load balancer vers le conteneur API."
  type        = string
  default     = "/health"
}

variable "desired_count" {
  description = "Nombre de taches Fargate souhaite (1 minimise le cout en dev)."
  type        = number
  default     = 1

  validation {
    condition     = var.desired_count >= 0
    error_message = "desired_count doit etre superieur ou egal a 0."
  }
}

variable "task_cpu" {
  description = "Unites CPU Fargate (256 = 0.25 vCPU)."
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Memoire Fargate en Mo (512 avec 256 CPU est le couple minimal valide)."
  type        = number
  default     = 512
}

variable "log_retention_days" {
  description = "Retention des logs CloudWatch (1 a 3 jours limite le cout en dev)."
  type        = number
  default     = 3
}

variable "assign_public_ip" {
  description = "Si true, les taches recoivent une IP publique pour sortir sur Internet (pull ECR, logs) sans NAT Gateway."
  type        = bool
  default     = true
}

variable "container_environment" {
  description = "Variables environnement injectees dans le conteneur (valeurs en clair dans la task definition)."
  type        = map(string)
  default     = {}
}

variable "container_secrets" {
  description = "Secrets injectes dans le conteneur via Secrets Manager (reference ARN, pas la valeur)."
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}

variable "acm_certificate_arn" {
  description = "ARN du certificat ACM utilise par le listener HTTPS de l'ALB."
  type        = string
}
