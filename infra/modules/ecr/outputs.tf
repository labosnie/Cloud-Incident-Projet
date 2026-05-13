output "repository_url" {
  description = "URL du repository ECR (sans tag d'image)."
  value       = aws_ecr_repository.app.repository_url
}

output "repository_arn" {
  description = "ARN du repository ECR."
  value       = aws_ecr_repository.app.arn
}
