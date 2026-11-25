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

# ---- Artifacts Bucket ---------------------------------------
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
      sse_algorithm = "aws:kms"
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

    filter {}

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
        Sid       = "DenyNonTLS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*"
        ]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      },
      {
        Sid       = "AllowCodePipeline"
        Effect    = "Allow"
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

# ---- Access Logging Bucket ----------------------------------
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
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    id     = "expire-access-logs"
    status = "Enabled"

    filter {}

    expiration { days = 90 }
    noncurrent_version_expiration { noncurrent_days = 7 }
    abort_incomplete_multipart_upload { days_after_initiation = 1 }
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
  tags              = { Name = "${var.organization_name}-${var.environment}-pipeline-logs" }
}

# ---- Data sources for dynamic values -----------------------
data "aws_caller_identity" "current" {}
