output "state_bucket_name" {
  description = "Nom du bucket S3 à mettre dans backend.hcl (bucket = ...)."
  value       = aws_s3_bucket.terraform_state.id
}

output "lock_table_name" {
  description = "Nom de la table DynamoDB à mettre dans backend.hcl (dynamodb_table = ...)."
  value       = aws_dynamodb_table.terraform_locks.name
}

output "aws_region" {
  description = "Région utilisée pour le backend."
  value       = var.aws_region
}
