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
