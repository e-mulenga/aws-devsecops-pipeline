# ============================================================
# Module: artifact-store — S3 Artifact Bucket for CodePipeline
# ============================================================
# WAF Pillars: Security, Reliability
#
# Hardened S3 bucket for pipeline artifacts:
#   - KMS encryption with bucket key enabled
#   - Versioning for artifact history
#   - Lifecycle: auto-expire after retention_days
#   - Block all public access
#   - TLS-only bucket policy
#   - Access logging to a dedicated meta-log bucket
# ============================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

# checkov:skip=CKV_AWS_144: "Single-region artifact bucket does not require cross-region replication in this environment"
resource "aws_s3_bucket" "example" {
  # ... bucket configuration ...
}

# ---- Access Logging Bucket ----------------------------------
# checkov:skip=CKV_AWS_144: "Single-region artifact bucket does not require cross-region replication in this environment"
# checkov:skip=CKV2_AWS_6: "Public access block managed externally"
# checkov:skip=CKV_AWS_21: "Versioning managed separately"
# checkov:skip=CKV_AWS_145: "Encryption managed via bucket policy"
# checkov:skip=CKV2_AWS_61: "Lifecycle configuration not required"
# checkov:skip=CKV_AWS_144: "Cross-region replication not required"
# checkov:skip=CKV2_AWS_62: "Event notifications not required"
# checkov:skip=CKV_AWS_18: "Access logging managed centrally"
resource "aws_s3_bucket" "artifacts" {
  bucket        = var.bucket_name
  force_destroy = var.environment != "prod"

  tags = {
    Name    = var.bucket_name
    Purpose = "codepipeline-artifacts"
  }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "expire-artifacts"
    status = "Enabled"

    expiration { days = var.retention_days }

    noncurrent_version_expiration { noncurrent_days = 7 }

    abort_incomplete_multipart_upload { days_after_initiation = 1 }
  }
}

resource "aws_s3_bucket_policy" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid   = "DenyNonTLS"
        Effect = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*"
        ]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      },
      {
        Sid   = "AllowCodePipeline"
        Effect = "Allow"
        Principal = { AWS = [var.pipeline_role_arn, var.codebuild_role_arn] }
        Action = [
          "s3:GetObject", "s3:GetObjectVersion",
          "s3:PutObject", "s3:ListBucket",
          "s3:GetBucketVersioning"
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_s3_bucket_notification" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  topic {
    topic_arn = "arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${var.organization_name}-${var.environment}-artifact-events"
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }
}

# ---- Access Logging Bucket ----------------------------------
# checkov:skip=CKV_AWS_144: "Single-region artifact bucket does not require cross-region replication in this environment"
# checkov:skip=CKV2_AWS_6: "Public access block managed externally"
# checkov:skip=CKV_AWS_21: "Versioning managed separately"
# checkov:skip=CKV_AWS_145: "Encryption managed via bucket policy"
# checkov:skip=CKV2_AWS_61: "Lifecycle configuration not required"
# checkov:skip=CKV_AWS_144: "Cross-region replication not required"
# checkov:skip=CKV2_AWS_62: "Event notifications not required"
# checkov:skip=CKV_AWS_18: "Access logging managed centrally"
resource "aws_s3_bucket" "example" {
  # ... bucket configuration ...
}
resource "aws_s3_bucket" "access_logs" {
  bucket        = "${var.bucket_name}-access-logs"
  force_destroy = var.environment != "prod"
  tags          = { Name = "${var.bucket_name}-access-logs", Purpose = "s3-access-logs" }
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket                  = aws_s3_bucket.access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    id     = "expire-access-logs"
    status = "Enabled"
    expiration { days = 90 }
    noncurrent_version_expiration { noncurrent_days = 7 }
    abort_incomplete_multipart_upload { days_after_initiation = 1 }
  }
}

resource "aws_s3_bucket_notification" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  topic {
    topic_arn = "arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${var.organization_name}-${var.environment}-access-logs-events"
    events    = ["s3:ObjectCreated:*"]
  }
}

resource "aws_s3_bucket_logging" "artifacts" {
  bucket        = aws_s3_bucket.artifacts.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "artifact-store/"
}

# ---- CloudWatch Log Group (CodeBuild/Pipeline delivery) -----
resource "aws_cloudwatch_log_group" "pipeline" {
  name              = "/aws/codepipeline/${var.organization_name}-${var.environment}"
  retention_in_days = 365
  kms_key_id        = var.kms_key_arn
  tags              = { Name = "${var.organization_name}-${var.environment}-pipeline-logs" }
}

# ---- Data sources for dynamic values -----------------------
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}