# ============================================================
# Module: codebuild — All Pipeline Build Projects
# ============================================================
# WAF Pillars: Security, Operational Excellence, Reliability
#
# Provisions one CodeBuild project per pipeline stage:
#   1.  secret-scan      — gitleaks secrets detection
#   2.  sast             — Semgrep + CodeGuru SAST
#   3.  build            — docker build + unit tests
#   4.  container-scan   — Trivy + Inspector findings
#   5.  iac-scan         — tfsec + checkov
#   6.  sbom             — Syft SBOM generation
#   7.  integration-test — pytest/newman integration tests
#   8.  dast             — OWASP ZAP active scan
#   9.  deploy-dev       — kubectl/terraform apply to dev
#   10. deploy-test      — kubectl/terraform apply to test
#   11. deploy-prod      — kubectl/terraform apply to prod
# ============================================================

locals {
  name_prefix = "${var.organization_name}-${var.environment}"

  # Common environment variables injected into every project
  common_env = [
    { name = "ORGANIZATION_NAME", value = var.organization_name, type = "PLAINTEXT" },
    { name = "AWS_REGION", value = var.region, type = "PLAINTEXT" },
    { name = "AWS_ACCOUNT_ID", value = var.account_id, type = "PLAINTEXT" },
    { name = "ENVIRONMENT", value = var.environment, type = "PLAINTEXT" },
  ]

  # VPC config block — only when vpc_id is provided
  vpc_config = var.vpc_id != "" ? [{
    vpc_id             = var.vpc_id
    subnets            = var.private_subnet_ids
    security_group_ids = var.security_group_ids
  }] : []

  # ---- Project definitions map --------------------------------
  projects = {
    "secret-scan" = {
      description  = "Secrets detection with gitleaks"
      buildspec    = "buildspecs/buildspec-secret-scan.yml"
      timeout      = 15
      compute_type = "BUILD_GENERAL1_SMALL"
      privileged   = false
      extra_env    = []
    }
    "sast" = {
      description  = "Static Application Security Testing — Semgrep + CodeGuru"
      buildspec    = "buildspecs/buildspec-sast.yml"
      timeout      = 30
      compute_type = var.build_compute_type
      privileged   = false
      extra_env = [
        { name = "SAST_FAILURE_ACTION", value = var.sast_failure_action, type = "PLAINTEXT" }
      ]
    }
    "build" = {
      description  = "Application build, unit tests, Docker image"
      buildspec    = "buildspecs/buildspec-build.yml"
      timeout      = var.build_timeout_minutes
      compute_type = var.build_compute_type
      privileged   = true # Required for Docker daemon
      extra_env = concat(
        [for name, url in var.ecr_repository_urls :
          { name = "ECR_REPO_${upper(replace(name, "-", "_"))}", value = url, type = "PLAINTEXT" }
        ],
        var.codeartifact_domain != "" ? [
          { name = "CODEARTIFACT_DOMAIN", value = var.codeartifact_domain, type = "PLAINTEXT" },
          { name = "CODEARTIFACT_REPOSITORY", value = var.codeartifact_repository, type = "PLAINTEXT" }
        ] : []
      )
    }
    "container-scan" = {
      description  = "Container image vulnerability scan — Trivy + Inspector"
      buildspec    = "buildspecs/buildspec-container-scan.yml"
      timeout      = 30
      compute_type = var.build_compute_type
      privileged   = false
      extra_env = [
        { name = "SCAN_SEVERITY_THRESHOLD", value = var.container_scan_severity, type = "PLAINTEXT" }
      ]
    }
    "iac-scan" = {
      description  = "Infrastructure-as-Code security scan — tfsec + checkov"
      buildspec    = "buildspecs/buildspec-iac-scan.yml"
      timeout      = 20
      compute_type = "BUILD_GENERAL1_SMALL"
      privileged   = false
      extra_env    = []
    }
    "sbom" = {
      description  = "Software Bill of Materials generation — Syft"
      buildspec    = "buildspecs/buildspec-sbom.yml"
      timeout      = 20
      compute_type = "BUILD_GENERAL1_SMALL"
      privileged   = false
      extra_env    = []
    }
    "integration-test" = {
      description  = "Integration and API tests against dev environment"
      buildspec    = "buildspecs/buildspec-integration-test.yml"
      timeout      = 30
      compute_type = var.build_compute_type
      privileged   = false
      extra_env = [
        { name = "TEST_ENV_ACCOUNT_ID", value = var.dev_account_id, type = "PLAINTEXT" }
      ]
    }
    "dast" = {
      description  = "Dynamic Application Security Testing — OWASP ZAP"
      buildspec    = "buildspecs/buildspec-dast.yml"
      timeout      = 30
      compute_type = var.build_compute_type
      privileged   = true
      extra_env    = []
    }
    "deploy-dev" = {
      description  = "Deploy to Development account"
      buildspec    = "buildspecs/buildspec-deploy.yml"
      timeout      = 30
      compute_type = "BUILD_GENERAL1_SMALL"
      privileged   = false
      extra_env = [
        { name = "DEPLOY_ACCOUNT_ID", value = var.dev_account_id, type = "PLAINTEXT" },
        { name = "DEPLOY_ENV", value = "dev", type = "PLAINTEXT" }
      ]
    }
    "deploy-test" = {
      description  = "Deploy to Test account"
      buildspec    = "buildspecs/buildspec-deploy.yml"
      timeout      = 30
      compute_type = "BUILD_GENERAL1_SMALL"
      privileged   = false
      extra_env = [
        { name = "DEPLOY_ACCOUNT_ID", value = var.test_account_id, type = "PLAINTEXT" },
        { name = "DEPLOY_ENV", value = "test", type = "PLAINTEXT" }
      ]
    }
    "deploy-prod" = {
      description  = "Deploy to Production account"
      buildspec    = "buildspecs/buildspec-deploy.yml"
      timeout      = 30
      compute_type = "BUILD_GENERAL1_SMALL"
      privileged   = false
      extra_env = [
        { name = "DEPLOY_ACCOUNT_ID", value = var.prod_account_id, type = "PLAINTEXT" },
        { name = "DEPLOY_ENV", value = "prod", type = "PLAINTEXT" }
      ]
    }
  }
}

# ---- CodeBuild Projects (for_each over project map) ---------
resource "aws_codebuild_project" "main" {
  for_each = local.projects

  name          = "${local.name_prefix}-${each.key}"
  description   = each.value.description
  service_role  = var.codebuild_role_arn
  build_timeout = each.value.timeout

  artifacts {
    type = "CODEPIPELINE"
  }

  cache {
    type  = "LOCAL"
    modes = ["LOCAL_SOURCE_CACHE", "LOCAL_DOCKER_LAYER_CACHE"]
  }

  environment {
    compute_type                = each.value.compute_type
    image                       = var.build_image
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = each.value.privileged

    dynamic "environment_variable" {
      for_each = concat(local.common_env, each.value.extra_env)
      content {
        name  = environment_variable.value.name
        value = environment_variable.value.value
        type  = environment_variable.value.type
      }
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = each.value.buildspec
  }

  dynamic "vpc_config" {
    for_each = local.vpc_config
    content {
      vpc_id             = vpc_config.value.vpc_id
      subnets            = vpc_config.value.subnets
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.projects[each.key].name
      stream_name = "build"
      status      = "ENABLED"
    }
    s3_logs {
      encryption_disabled = false
      location            = "${var.artifact_bucket_name}/codebuild-logs/${each.key}"
      status              = "ENABLED"
    }
  }

  encryption_key = var.kms_key_arn

  tags = { Stage = each.key, Purpose = "devsecops-pipeline" }
}
