output "vpc_id" {
  description = "ID du VPC."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs des subnets publics."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs des subnets privés."
  value       = module.vpc.private_subnet_ids
}

output "ecr_repository_url" {
  description = "URL du repository ECR."
  value       = module.ecr.repository_url
}

output "alb_dns_name" {
  description = "URL de base de l’API via l’ALB (ex. http://<dns>/health)."
  value       = module.ecs.alb_dns_name
}

output "ecs_cluster_name" {
  description = "Nom du cluster ECS."
  value       = module.ecs.cluster_name
}

output "ecs_log_group_name" {
  description = "Groupe CloudWatch Logs des tâches API."
  value       = module.ecs.log_group_name
}

output "sns_topic_arn" {
  description = "ARN du topic SNS alertes."
  value       = module.monitoring.sns_topic_arn
}

output "alarm_5xx_name" {
  description = "Nom alarme CloudWatch 5XX."
  value       = module.monitoring.alarm_5xx_name
}

output "alarm_latency_name" {
  description = "Nom alarme CloudWatch latence."
  value       = module.monitoring.alarm_latency_name
}
