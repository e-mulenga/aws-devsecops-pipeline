# ============================================================
# AWS DevSecOps Pipeline — Variables
# ============================================================
# All configurable values are variables. No account IDs,
# regions, emails, secrets, or environment names are hardcoded.
# ============================================================

# ---- Identity & Organisation --------------------------------
variable "organization_name" {
  type        = string
  description = "Short organisation name used in all resource naming (3-30 lowercase chars)."
  validation {
    condition     = can(regex("^[a-z0-9-]{3,30}$", var.organization_name))
    error_message = "organization_name must be 3-30 lowercase alphanumeric characters or hyphens."
  }
}

variable "aws_region" {
  type        = string
  description = "Primary AWS region for the pipeline infrastructure."
  default     = "af-south-1"
}

variable "environment" {
  type        = string
  description = "Deployment tier for the pipeline account itself: dev | test | prod."
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, prod."
  }
}

# ---- Governance & Tagging -----------------------------------
variable "owner" {
  type        = string
  description = "Team responsible for this pipeline."
}

variable "cost_center" {
  type        = string
  description = "Cost center code for billing allocation."
}

# ---- Target Account IDs (from landing zone outputs) ---------
variable "dev_account_id" {
  type        = string
  description = "AWS Account ID for the Development workload account."
}

variable "test_account_id" {
  type        = string
  description = "AWS Account ID for the Test workload account."
}

variable "prod_account_id" {
  type        = string
  description = "AWS Account ID for the Production workload account."
}

variable "shared_services_account_id" {
  type        = string
  description = "AWS Account ID for the Shared Services account."
}

# ---- Landing Zone Inputs ------------------------------------
variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN from the Landing Zone for encrypting pipeline artifacts."
  sensitive   = true
}

variable "cloudtrail_bucket_name" {
  type        = string
  description = "Centralised CloudTrail S3 bucket name from the Landing Zone."
}

# ---- Pipeline Source ----------------------------------------
variable "source_provider" {
  type        = string
  description = "Source provider for CodePipeline: GitHub | CodeStarSourceConnection | CodeCommit."
  default     = "CodeStarSourceConnection"
  validation {
    condition     = contains(["CodeStarSourceConnection", "CodeCommit", "GitHub"], var.source_provider)
    error_message = "source_provider must be CodeStarSourceConnection, CodeCommit, or GitHub."
  }
}

variable "github_connection_arn" {
  type        = string
  description = "CodeStar connection ARN for GitHub integration. Created manually in AWS Console."
  default     = ""
  sensitive   = true
}

variable "repository_name" {
  type        = string
  description = "Source repository name (GitHub org/repo or CodeCommit repo name)."
}

variable "branch_name" {
  type        = string
  description = "Source branch that triggers the pipeline."
  default     = "main"
}

# ---- Container Registry -------------------------------------
variable "ecr_repository_names" {
  type        = list(string)
  description = "List of ECR repository names to create."
  default     = ["app", "sidecar", "init"]
}

variable "ecr_image_retention_count" {
  type        = number
  description = "Number of tagged images to retain per ECR repository."
  default     = 30
}

variable "ecr_scan_on_push" {
  type        = bool
  description = "Enable automatic ECR image scanning on push using Amazon Inspector."
  default     = true
}

# ---- Build Configuration ------------------------------------
variable "build_compute_type" {
  type        = string
  description = "CodeBuild compute type for build stages."
  default     = "BUILD_GENERAL1_MEDIUM"
  validation {
    condition = contains([
      "BUILD_GENERAL1_SMALL", "BUILD_GENERAL1_MEDIUM",
      "BUILD_GENERAL1_LARGE", "BUILD_GENERAL1_2XLARGE"
    ], var.build_compute_type)
    error_message = "Invalid CodeBuild compute type."
  }
}

variable "build_image" {
  type        = string
  description = "CodeBuild Docker image for standard build stages."
  default     = "aws/codebuild/standard:7.0"
}

variable "build_timeout_minutes" {
  type        = number
  description = "Maximum build timeout in minutes."
  default     = 60
  validation {
    condition     = var.build_timeout_minutes >= 5 && var.build_timeout_minutes <= 480
    error_message = "build_timeout_minutes must be between 5 and 480."
  }
}

# ---- Security Scanning Configuration -----------------------
variable "sast_enabled" {
  type        = bool
  description = "Enable Static Application Security Testing (SAST) stage."
  default     = true
}

variable "dast_enabled" {
  type        = bool
  description = "Enable Dynamic Application Security Testing (DAST) stage."
  default     = true
}

variable "sbom_enabled" {
  type        = bool
  description = "Enable Software Bill of Materials (SBOM) generation."
  default     = true
}

variable "iac_scan_enabled" {
  type        = bool
  description = "Enable IaC security scanning (tfsec + checkov) in the pipeline."
  default     = true
}

variable "dependency_scan_enabled" {
  type        = bool
  description = "Enable dependency vulnerability scanning (OWASP Dependency-Check)."
  default     = true
}

variable "secret_scan_enabled" {
  type        = bool
  description = "Enable secrets detection (gitleaks) in the pre-build stage."
  default     = true
}

# ---- Quality Gates ------------------------------------------
variable "sast_failure_action" {
  type        = string
  description = "Action on SAST failure: BLOCK | WARN."
  default     = "BLOCK"
  validation {
    condition     = contains(["BLOCK", "WARN"], var.sast_failure_action)
    error_message = "sast_failure_action must be BLOCK or WARN."
  }
}

variable "container_scan_severity_threshold" {
  type        = string
  description = "Minimum severity to fail the pipeline on container scan: CRITICAL | HIGH | MEDIUM."
  default     = "HIGH"
  validation {
    condition     = contains(["CRITICAL", "HIGH", "MEDIUM", "LOW"], var.container_scan_severity_threshold)
    error_message = "Must be CRITICAL, HIGH, MEDIUM, or LOW."
  }
}

# ---- Approval Settings --------------------------------------
variable "require_test_approval" {
  type        = bool
  description = "Require manual approval before deploying to the test environment."
  default     = true
}

variable "require_prod_approval" {
  type        = bool
  description = "Require manual approval before deploying to production."
  default     = true
}

variable "approval_notification_email" {
  type        = string
  description = "Email address for manual approval notifications."
  default     = ""
}

# ---- Artifact Store ----------------------------------------
variable "artifact_bucket_name" {
  type        = string
  description = "S3 bucket name for CodePipeline artifact storage."
}

variable "artifact_retention_days" {
  type        = number
  description = "Days to retain pipeline artifacts in S3."
  default     = 30
}

# ---- CodeArtifact -------------------------------------------
variable "codeartifact_domain_name" {
  type        = string
  description = "CodeArtifact domain name for package management."
  default     = ""
}

variable "codeartifact_enabled" {
  type        = bool
  description = "Enable AWS CodeArtifact as the private package registry."
  default     = true
}

# ---- Notifications ------------------------------------------
variable "pipeline_notification_email" {
  type        = string
  description = "Email address for pipeline success/failure notifications."
  default     = ""
}

variable "slack_webhook_secret_arn" {
  type        = string
  description = "Secrets Manager ARN for the Slack webhook URL (optional)."
  default     = ""
  sensitive   = true
}

# ---- VPC (for private CodeBuild) ----------------------------
variable "vpc_id" {
  type        = string
  description = "VPC ID for running CodeBuild projects in a private subnet. Leave empty for public."
  default     = ""
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for VPC-hosted CodeBuild projects."
  default     = []
}

variable "codebuild_security_group_ids" {
  type        = list(string)
  description = "Security group IDs for CodeBuild VPC access."
  default     = []
}

# ---- Monitoring ---------------------------------------------
variable "log_retention_days" {
  type        = number
  description = "CloudWatch Logs retention in days."
  default     = 90
}

variable "pipeline_alarm_threshold_failures" {
  type        = number
  description = "Number of pipeline failures before triggering a CloudWatch alarm."
  default     = 3
}
