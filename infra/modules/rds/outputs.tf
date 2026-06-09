output "db_endpoint" {
  description = "Hostname RDS PostgreSQL (sans port)."
  value       = aws_db_instance.main.address
}

output "db_port" {
  description = "Port PostgreSQL."
  value       = aws_db_instance.main.port
}

output "security_group_id" {
  description = "Security group ID du RDS."
  value       = aws_security_group.rds.id
}

output "db_instance_id" {
  description = "ID de l'instance RDS."
  value       = aws_db_instance.main.id
}
