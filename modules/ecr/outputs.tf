output "repository_urls" {
  description = "Map of repository name to URL."
  value       = { for k, v in aws_ecr_repository.main : k => v.repository_url }
}
output "repository_arns" {
  description = "Map of repository name to ARN."
  value       = { for k, v in aws_ecr_repository.main : k => v.arn }
}
output "repository_names" {
  description = "Map of repository short name to full ECR name."
  value       = { for k, v in aws_ecr_repository.main : k => v.name }
}
