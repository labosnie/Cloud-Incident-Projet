output "cluster_name" {
  description = "Nom du cluster ECS."
  value       = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  description = "ARN du cluster ECS."
  value       = aws_ecs_cluster.main.arn
}

output "service_name" {
  description = "Nom du service ECS."
  value       = aws_ecs_service.app.name
}

output "alb_dns_name" {
  description = "DNS public de l’ALB (ex. http://<valeur>/health)."
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN de l’Application Load Balancer."
  value       = aws_lb.main.arn
}

output "target_group_arn" {
  description = "ARN du target group HTTP vers le conteneur."
  value       = aws_lb_target_group.app.arn
}

output "log_group_name" {
  description = "Nom du groupe de logs CloudWatch des tâches."
  value       = aws_cloudwatch_log_group.ecs.name
}
