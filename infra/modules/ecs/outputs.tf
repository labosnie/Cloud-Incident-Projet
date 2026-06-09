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
  description = "DNS public du load balancer (exemple http://valeur/health)."
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN du Application Load Balancer."
  value       = aws_lb.main.arn
}

output "alb_arn_suffix" {
  description = "Suffixe ARN ALB pour dimensions CloudWatch (app/nom/id)."
  value       = element(split("loadbalancer/", aws_lb.main.arn), 1)
}

output "target_group_arn" {
  description = "ARN du target group HTTP vers le conteneur."
  value       = aws_lb_target_group.app.arn
}

output "target_group_arn_suffix" {
  description = "Suffixe ARN target group pour dimensions CloudWatch (targetgroup/nom/id)."
  value       = replace(aws_lb_target_group.app.arn, "/^arn:aws:elasticloadbalancing:[^:]+:[0-9]+:/", "")
}

output "log_group_name" {
  description = "Nom du groupe de logs CloudWatch des taches."
  value       = aws_cloudwatch_log_group.ecs.name
}

output "tasks_security_group_id" {
  description = "Security group ID des taches ECS."
  value       = aws_security_group.tasks.id
}
