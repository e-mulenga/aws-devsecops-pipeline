# ============================================================
# AWS DevSecOps Pipeline — Root Orchestration
# ============================================================
# Composes all pipeline modules into a complete, end-to-end
# secure CI/CD pipeline with embedded security gates.
#
# Pipeline Stages:
#   Source → Secret Scan → SAST → Build → Container Scan →
#   IaC Scan → SBOM → Integration Test → DAST →
#   Deploy DEV → [Approval] → Deploy TEST →
#   [Approval + CAB] → Deploy PROD
# ============================================================

# Every resource below runs in Ireland (eu-west-1) through provider alias aws.ireland. Container images are pushed to the
# Landing Zone ECR repository in af-south-1 (landing_zone.tf); CodeBuild logs in to that registry cross-Region.

data "aws_region" "ireland" {
  provider = aws.ireland
}

# ---- 1. Pipeline IAM Roles ----------------------------------
module "pipeline_iam" {
  source    = "./modules/pipeline-iam"
  providers = { aws = aws.ireland }

  organization_name        = var.organization_name
  environment              = var.environment
  account_id               = local.account_id
  partition                = local.partition
  region                   = data.aws_region.ireland.name
  artifact_bucket_name     = var.artifact_bucket_name
  dev_account_id           = local.dev_account_id
  test_account_id          = local.test_account_id # Used for cross-account access to the test account for integration testing
  prod_account_id          = local.prod_account_id
  codeartifact_domain_name = var.codeartifact_domain_name
  codeartifact_enabled     = var.codeartifact_enabled
  ecr_repository_arn       = local.ecr_repository_arn
}

# ---- 2. Artifact Store (S3) ---------------------------------
module "artifact_store" {
  source    = "./modules/artifact-store"
  providers = { aws = aws.ireland }

  organization_name  = var.organization_name
  environment        = var.environment
  bucket_name        = var.artifact_bucket_name
  retention_days     = var.artifact_retention_days
  pipeline_role_arn  = module.pipeline_iam.codepipeline_role_arn
  codebuild_role_arn = module.pipeline_iam.codebuild_role_arn
  log_retention_days = var.log_retention_days
}

# ---- 4. CodeArtifact (Package Registry) ---------------------
module "codeartifact" {
  source    = "./modules/codeartifact"
  providers = { aws = aws.ireland }
  count     = var.codeartifact_enabled ? 1 : 0

  organization_name  = var.organization_name
  environment        = var.environment
  domain_name        = coalesce(var.codeartifact_domain_name, "${var.organization_name}-${var.environment}")
  codebuild_role_arn = module.pipeline_iam.codebuild_role_arn
  account_id         = local.account_id
  kms_key_arn        = var.kms_key_arn
}

# ---- 5. CodeBuild Projects ----------------------------------
module "codebuild" {
  source    = "./modules/codebuild"
  providers = { aws = aws.ireland }

  organization_name       = var.organization_name
  environment             = var.environment
  region                  = data.aws_region.ireland.name
  account_id              = local.account_id
  codebuild_role_arn      = module.pipeline_iam.codebuild_role_arn
  artifact_bucket_name    = var.artifact_bucket_name
  build_image             = var.build_image
  build_compute_type      = var.build_compute_type
  build_timeout_minutes   = var.build_timeout_minutes
  vpc_id                  = var.vpc_id
  private_subnet_ids      = var.private_subnet_ids
  security_group_ids      = var.codebuild_security_group_ids
  log_retention_days      = var.log_retention_days
  ecr_repository_url      = local.ecr_repository_url
  ecr_region              = local.ecr_region
  workload_region         = var.primary_region
  sast_enabled            = var.sast_enabled
  dast_enabled            = var.dast_enabled
  sbom_enabled            = var.sbom_enabled
  iac_scan_enabled        = var.iac_scan_enabled
  dependency_scan_enabled = var.dependency_scan_enabled
  secret_scan_enabled     = var.secret_scan_enabled
  sast_failure_action     = var.sast_failure_action
  container_scan_severity = var.container_scan_severity_threshold
  codeartifact_domain     = var.codeartifact_enabled ? module.codeartifact[0].domain_name : ""
  codeartifact_repository = var.codeartifact_enabled ? module.codeartifact[0].repository_name : ""
  dev_account_id          = local.dev_account_id
  test_account_id         = local.test_account_id
  prod_account_id         = local.prod_account_id

  depends_on = [module.artifact_store, module.pipeline_iam]
}

# ---- 6. Notifications ---------------------------------------
module "notifications" {
  source    = "./modules/notifications"
  providers = { aws = aws.ireland }

  organization_name           = var.organization_name
  environment                 = var.environment
  pipeline_notification_email = var.pipeline_notification_email
  approval_notification_email = var.approval_notification_email
  slack_webhook_secret_arn    = var.slack_webhook_secret_arn
  log_retention_days          = var.log_retention_days
  account_id                  = local.account_id
  region                      = data.aws_region.ireland.name
}

# ---- 7. CodePipeline ----------------------------------------
module "codepipeline" {
  source    = "./modules/codepipeline"
  providers = { aws = aws.ireland }

  organization_name             = var.organization_name
  environment                   = var.environment
  region                        = data.aws_region.ireland.name
  account_id                    = local.account_id
  pipeline_role_arn             = module.pipeline_iam.codepipeline_role_arn
  artifact_bucket_name          = module.artifact_store.bucket_name
  source_provider               = var.source_provider
  github_connection_arn         = var.github_connection_arn
  repository_name               = var.repository_name
  branch_name                   = var.branch_name
  sast_project_name             = module.codebuild.sast_project_name
  secret_scan_project_name      = module.codebuild.secret_scan_project_name
  build_project_name            = module.codebuild.build_project_name
  container_scan_project_name   = module.codebuild.container_scan_project_name
  iac_scan_project_name         = module.codebuild.iac_scan_project_name
  sbom_project_name             = module.codebuild.sbom_project_name
  integration_test_project_name = module.codebuild.integration_test_project_name
  dast_project_name             = module.codebuild.dast_project_name
  deploy_dev_project_name       = module.codebuild.deploy_dev_project_name
  deploy_test_project_name      = module.codebuild.deploy_test_project_name
  deploy_prod_project_name      = module.codebuild.deploy_prod_project_name
  approval_sns_topic_arn        = module.notifications.approval_topic_arn
  require_test_approval         = var.require_test_approval
  require_prod_approval         = var.require_prod_approval
  sast_enabled                  = var.sast_enabled
  dast_enabled                  = var.dast_enabled
  sbom_enabled                  = var.sbom_enabled
  iac_scan_enabled              = var.iac_scan_enabled

  depends_on = [module.codebuild, module.notifications]
}

# ---- 8. CloudWatch Pipeline Monitoring ----------------------
resource "aws_cloudwatch_metric_alarm" "pipeline_failures" {
  provider            = aws.ireland
  count               = var.enable_alarms ? 1 : 0
  alarm_name          = "${local.name_prefix}-pipeline-failures"
  alarm_description   = "CodePipeline execution failures exceeded threshold"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "FailedPipelines"
  namespace           = "AWS/CodePipeline"
  period              = 300
  statistic           = "Sum"
  threshold           = var.pipeline_alarm_threshold_failures
  treat_missing_data  = "notBreaching"
  alarm_actions       = [module.notifications.alerts_topic_arn]

  dimensions = {
    PipelineName = module.codepipeline.pipeline_name
  }

  tags = { Name = "${local.name_prefix}-pipeline-failure-alarm" }
}

resource "aws_cloudwatch_dashboard" "pipeline" {
  provider       = aws.ireland
  count          = var.enable_alarms ? 1 : 0
  dashboard_name = "${local.name_prefix}-devsecops-pipeline"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2
        properties = {
          region   = var.ireland_region
          markdown = "# DevSecOps Pipeline Dashboard — ${upper(var.environment)}\n**Organisation:** ${var.organization_name} | **Pipeline:** ${module.codepipeline.pipeline_name}"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 2
        width  = 8
        height = 6
        properties = {
          region = var.ireland_region
          title  = "Pipeline Executions"
          period = 86400
          stat   = "Sum"
          view   = "timeSeries"
          metrics = [
            ["AWS/CodePipeline", "PipelineExecutionAttempts", "PipelineName", module.codepipeline.pipeline_name],
            ["AWS/CodePipeline", "FailedPipelines", "PipelineName", module.codepipeline.pipeline_name]
          ]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 2
        width  = 8
        height = 6
        properties = {
          region = var.ireland_region
          title  = "Build Duration (avg)"
          period = 3600
          stat   = "Average"
          view   = "timeSeries"
          metrics = [
            ["AWS/CodeBuild", "Duration", "ProjectName", module.codebuild.build_project_name]
          ]
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 2
        width  = 8
        height = 6
        properties = {
          region = var.ireland_region
          title  = "Security Gate Failures"
          period = 86400
          stat   = "Sum"
          view   = "timeSeries"
          metrics = [
            ["AWS/CodeBuild", "FailedBuilds", "ProjectName", module.codebuild.sast_project_name],
            ["AWS/CodeBuild", "FailedBuilds", "ProjectName", module.codebuild.container_scan_project_name]
          ]
        }
      }
    ]
  })
}
