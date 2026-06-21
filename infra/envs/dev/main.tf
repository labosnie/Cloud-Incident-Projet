locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

module "vpc" {
  source = "../../modules/vpc"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "ecr" {
  source = "../../modules/ecr"

  repository_name = var.ecr_repository_name
}

module "rds" {
  source = "../../modules/rds"

  name_prefix            = local.name_prefix
  vpc_id                 = module.vpc.vpc_id
  private_subnet_ids     = module.vpc.private_subnet_ids
  db_name                = var.db_name
  db_username            = var.db_username
  db_password            = var.db_password
  db_instance_class      = var.db_instance_class
  db_allocated_storage   = var.db_allocated_storage
  db_engine_version      = var.db_engine_version
  db_skip_final_snapshot = var.db_skip_final_snapshot
  db_deletion_protection = var.db_deletion_protection
}

resource "aws_secretsmanager_secret" "database_url" {
  name        = "${local.name_prefix}-database-url"
  description = "PostgreSQL connection URL for ECS API (DATABASE_URL)."
}

resource "aws_secretsmanager_secret_version" "database_url" {
  secret_id     = aws_secretsmanager_secret.database_url.id
  secret_string = "postgresql+psycopg://${var.db_username}:${var.db_password}@${module.rds.db_endpoint}:5432/${var.db_name}"
}

module "ecs" {
  source = "../../modules/ecs"

  name_prefix        = local.name_prefix
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  container_image    = "${module.ecr.repository_url}:${var.ecs_image_tag}"
  container_port     = var.ecs_container_port
  health_check_path  = var.ecs_health_check_path
  desired_count      = var.ecs_desired_count
  task_cpu           = var.ecs_task_cpu
  task_memory        = var.ecs_task_memory
  log_retention_days = var.ecs_log_retention_days
  assign_public_ip   = var.ecs_assign_public_ip
  container_secrets = [
    {
      name      = "DATABASE_URL"
      valueFrom = aws_secretsmanager_secret.database_url.arn
    }
  ]

  depends_on = [aws_secretsmanager_secret_version.database_url]
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_ecs_tasks" {
  security_group_id            = module.rds.security_group_id
  referenced_security_group_id = module.ecs.tasks_security_group_id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "PostgreSQL from ECS tasks only"
}

module "monitoring" {
  source = "../../modules/monitoring"

  name_prefix             = local.name_prefix
  alb_arn_suffix          = module.ecs.alb_arn_suffix
  target_group_arn_suffix = module.ecs.target_group_arn_suffix
  alert_email             = var.alert_email
}
