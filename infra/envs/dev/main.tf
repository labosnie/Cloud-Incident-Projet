module "vpc" {
  source = "../../modules/vpc"

  name_prefix          = "${var.project_name}-${var.environment}"
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "ecr" {
  source = "../../modules/ecr"

  repository_name = var.ecr_repository_name
}

module "ecs" {
  source = "../../modules/ecs"

  name_prefix           = "${var.project_name}-${var.environment}"
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  container_image       = "${module.ecr.repository_url}:${var.ecs_image_tag}"
  container_port        = var.ecs_container_port
  health_check_path     = var.ecs_health_check_path
  desired_count         = var.ecs_desired_count
  task_cpu              = var.ecs_task_cpu
  task_memory           = var.ecs_task_memory
  log_retention_days    = var.ecs_log_retention_days
  assign_public_ip      = var.ecs_assign_public_ip
  container_environment = var.ecs_container_environment
}

module "monitoring" {
  source = "../../modules/monitoring"

  name_prefix             = "${var.project_name}-${var.environment}"
  alb_arn_suffix          = module.ecs.alb_arn_suffix
  target_group_arn_suffix = module.ecs.target_group_arn_suffix
  alert_email             = var.alert_email
}
