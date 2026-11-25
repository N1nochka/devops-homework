output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = module.s3_backend.bucket_name
}

output "s3_bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  value       = module.s3_backend.bucket_regional_domain_name
}

output "s3_bucket_url" {
  description = "HTTPS endpoint of the S3 bucket"
  value       = module.s3_backend.bucket_url
}

output "dynamodb_table_name" {
  description = "DynamoDB locking table name"
  value       = module.s3_backend.table_name
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = module.ecr.repository_url
}
