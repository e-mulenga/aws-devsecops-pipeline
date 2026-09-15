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

# ---- Artifacts Bucket ---------------------------------------
resource "aws_s3_bucket" "artifacts" {
  bucket        = var.bucket_name
  force_destroy = var.environment != "prod"

  tags = {
    Name    = var.bucket_name
    Purpose = "codepipeline-artifacts"
  }
}

# CKV_AWS_144 — cross-region replication for artifacts bucket
# Replicates pipeline artifacts to a secondary region for DR and audit retention.
# Requires: var.replication_role_arn, var.replication_destination_bucket_arn,
#           var.replication_destination_region — all supplied from the root module.
resource "aws_s3_bucket_replication_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  role   = var.replication_role_arn

  rule {
    id     = "replicate-artifacts"
    status = "Enabled"

    filter {}   # empty filter = replicate all objects

    destination {
      bucket        = var.replication_destination_bucket_arn
      storage_class = "STANDARD_IA"   # cheaper for DR copies

      encryption_configuration {
        replica_kms_key_id = var.replication_destination_kms_key_arn
      }
    }

    source_selection_criteria {
      sse_kms_encrypted_objects {
        status = "Enabled"   # required when source objects are KMS-encrypted
      }
    }

    delete_marker_replication {
      status = "Enabled"   # replicate deletions for full audit trail
    }
  }

  # Versioning must be enabled before replication can be configured
  depends_on = [aws_s3_bucket_versioning.artifacts]
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
resource "aws_s3_bucket" "access_logs" {
  bucket        = "${var.bucket_name}-access-logs"
  force_destroy = var.environment != "prod"
  tags          = { Name = "${var.bucket_name}-access-logs", Purpose = "s3-access-logs" }
}

# CKV_AWS_144 — cross-region replication for access logs bucket
# Replicates access logs to the secondary region for compliance and forensic retention.
resource "aws_s3_bucket_replication_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  role   = var.replication_role_arn

  rule {
    id     = "replicate-access-logs"
    status = "Enabled"

    filter {}   # replicate all objects

    destination {
      bucket        = var.replication_destination_logs_bucket_arn
      storage_class = "STANDARD_IA"

      encryption_configuration {
        replica_kms_key_id = var.replication_destination_kms_key_arn
      }
    }

    source_selection_criteria {
      sse_kms_encrypted_objects {
        status = "Enabled"
      }
    }

    delete_marker_replication {
      status = "Enabled"
    }
  }

  depends_on = [aws_s3_bucket_versioning.access_logs]
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
# ---- Replication Variables (added for CKV_AWS_144) ----------
# These are declared here for module completeness.
# Pass values from the root module — never hardcode ARNs.

variable "replication_role_arn" {
  description = "IAM role ARN that S3 assumes to replicate objects to the destination bucket. Must have s3:ReplicateObject, s3:ReplicateDelete, and KMS permissions."
  type        = string
}

variable "replication_destination_bucket_arn" {
  description = "ARN of the destination S3 bucket (secondary region) for artifacts replication."
  type        = string
}

variable "replication_destination_logs_bucket_arn" {
  description = "ARN of the destination S3 bucket (secondary region) for access logs replication."
  type        = string
}

variable "replication_destination_kms_key_arn" {
  description = "ARN of the KMS key in the destination region used to encrypt replicated objects."
  type        = string
}
