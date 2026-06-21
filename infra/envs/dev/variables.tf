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

variable "ecs_image_tag" {
  description = "Tag d’image déployé sur Fargate (ex. latest ou le digest Git)."
  type        = string
  default     = "latest"
}

variable "ecs_container_port" {
  description = "Port exposé par le conteneur (cohérent avec le Dockerfile / uvicorn)."
  type        = number
  default     = 8000
}

variable "ecs_health_check_path" {
  description = "Chemin du health check de l’ALB."
  type        = string
  default     = "/health"
}

variable "ecs_desired_count" {
  description = "Nombre de tâches Fargate (1 en dev, 0 pour arrêter la facturation tâche tout en gardant l’infra)."
  type        = number
  default     = 1
}

variable "ecs_task_cpu" {
  description = "CPU Fargate (256 = 0.25 vCPU, couple minimal avec 512 Mo)."
  type        = number
  default     = 256
}

variable "ecs_task_memory" {
  description = "Mémoire Fargate (Mo)."
  type        = number
  default     = 512
}

variable "ecs_log_retention_days" {
  description = "Rétention CloudWatch Logs pour les conteneurs (réduire le coût en dev)."
  type        = number
  default     = 3
}

variable "ecs_assign_public_ip" {
  description = "IP publique sur les tâches pour accès Internet sans NAT Gateway (recommandé true avec subnets publics)."
  type        = bool
  default     = true
}

variable "db_name" {
  description = "Nom de la base PostgreSQL RDS."
  type        = string
  default     = "orders"
}

variable "db_username" {
  description = "Utilisateur PostgreSQL RDS."
  type        = string
  default     = "app"
}

variable "db_password" {
  description = "Mot de passe PostgreSQL RDS (sensible, definir dans terraform.tfvars)."
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "Classe instance RDS (dev low-cost)."
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Stockage RDS en Go."
  type        = number
  default     = 20
}

variable "db_engine_version" {
  description = "Version PostgreSQL RDS (verifier dispo region : aws rds describe-db-engine-versions --engine postgres)."
  type        = string
  default     = "16.14"
}

variable "db_skip_final_snapshot" {
  description = "Pas de snapshot final a la suppression (dev jetable)."
  type        = bool
  default     = true
}

variable "db_deletion_protection" {
  description = "Protection suppression RDS."
  type        = bool
  default     = false
}

variable "alert_email" {
  description = "Email pour alertes SNS (confirmer la subscription AWS apres apply)."
  type        = string
}
