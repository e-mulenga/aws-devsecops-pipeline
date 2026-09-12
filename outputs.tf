# ============================================================
# AWS DevSecOps Pipeline — Outputs
# ============================================================
# Outputs consumed by downstream portfolio repositories:
#   - aws-cloud-security-operations-center
#   - aws-secure-eks-platform
# ============================================================

output "pipeline_name" {
  description = "Name of the CodePipeline pipeline."
  value       = module.codepipeline.pipeline_name
}

output "pipeline_arn" {
  description = "ARN of the CodePipeline pipeline."
  value       = module.codepipeline.pipeline_arn
}

output "artifact_bucket_name" {
  description = "S3 bucket storing pipeline artifacts."
  value       = module.artifact_store.bucket_name
}

output "artifact_bucket_arn" {
  description = "ARN of the pipeline artifact S3 bucket."
  value       = module.artifact_store.bucket_arn
}

output "ecr_repository_urls" {
  description = "Map of ECR repository name to URL."
  value       = module.ecr.repository_urls
}

output "ecr_repository_arns" {
  description = "Map of ECR repository name to ARN."
  value       = module.ecr.repository_arns
}

output "codebuild_role_arn" {
  description = "IAM role ARN used by CodeBuild projects."
  value       = module.pipeline_iam.codebuild_role_arn
}

output "codepipeline_role_arn" {
  description = "IAM role ARN used by CodePipeline."
  value       = module.pipeline_iam.codepipeline_role_arn
}

output "codeartifact_domain_name" {
  description = "CodeArtifact domain name for package management."
  value       = var.codeartifact_enabled ? module.codeartifact[0].domain_name : null
}

output "codeartifact_repository_endpoint" {
  description = "CodeArtifact repository endpoint for npm/pip/maven."
  value       = var.codeartifact_enabled ? module.codeartifact[0].repository_endpoint : null
  sensitive   = true
}

output "alerts_topic_arn" {
  description = "SNS topic ARN for pipeline alerts — consumed by aws-cloud-security-operations-center."
  value       = module.notifications.alerts_topic_arn
}

output "approval_topic_arn" {
  description = "SNS topic ARN for pipeline approval notifications."
  value       = module.notifications.approval_topic_arn
}

output "dashboard_name" {
  description = "CloudWatch dashboard name for pipeline observability."
  value       = aws_cloudwatch_dashboard.pipeline.dashboard_name
}

output "build_project_names" {
  description = "Map of all CodeBuild project names by stage."
  value = {
    secret_scan      = module.codebuild.secret_scan_project_name
    sast             = module.codebuild.sast_project_name
    build            = module.codebuild.build_project_name
    container_scan   = module.codebuild.container_scan_project_name
    iac_scan         = module.codebuild.iac_scan_project_name
    sbom             = module.codebuild.sbom_project_name
    integration_test = module.codebuild.integration_test_project_name
    dast             = module.codebuild.dast_project_name
    deploy_dev       = module.codebuild.deploy_dev_project_name
    deploy_test      = module.codebuild.deploy_test_project_name
    deploy_prod      = module.codebuild.deploy_prod_project_name
  }
}
