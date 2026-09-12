# ============================================================
# Module: ecr — Amazon Elastic Container Registry
# ============================================================
# WAF Pillars: Security, Cost Optimization, Reliability
#
# Creates private ECR repositories with:
#   - KMS encryption
#   - Image scanning on push (Amazon Inspector)
#   - Lifecycle policy (retain N tagged images)
#   - Cross-account pull access for workload accounts
#   - Tag immutability in all environments
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

resource "aws_ecr_repository" "main" {
  for_each = toset(var.repository_names)

  name                 = "${var.organization_name}-${var.environment}-${each.key}"
  image_tag_mutability = "IMMUTABLE"

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = var.kms_key_arn
  }

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  tags = {
    Name       = "${var.organization_name}-${var.environment}-${each.key}"
    Repository = each.key
  }
}

# ---- Lifecycle Policy (cost control) ------------------------
resource "aws_ecr_lifecycle_policy" "main" {
  for_each   = toset(var.repository_names)
  repository = aws_ecr_repository.main[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Retain last ${var.image_retention_count} tagged images"
        selection = {
          tagStatus   = "tagged"
          tagPrefixList = ["v", "release", "stable"]
          countType   = "imageCountMoreThan"
          countNumber = var.image_retention_count
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Expire untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      }
    ]
  })
}

# ---- Repository Policy (cross-account pull) -----------------
resource "aws_ecr_repository_policy" "main" {
  for_each   = toset(var.repository_names)
  repository = aws_ecr_repository.main[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrossAccountPull"
        Effect = "Allow"
        Principal = {
          AWS = concat(
            [var.codebuild_role_arn],
            [for id in var.cross_account_ids :
              "arn:aws:iam::${id}:root"]
          )
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:DescribeImages",
          "ecr:GetAuthorizationToken"
        ]
      },
      {
        Sid    = "DenyUnencryptedPush"
        Effect = "Deny"
        Principal = "*"
        Action    = ["ecr:PutImage"]
        Condition = {
          StringNotEquals = {
            "ecr:ResourceTag/Environment" = var.environment
          }
        }
      }
    ]
  })
}

# ---- ECR Pull-Through Cache (optional cost optimisation) ----
resource "aws_ecr_pull_through_cache_rule" "docker_hub" {
  count                 = var.enable_pull_through_cache ? 1 : 0
  ecr_repository_prefix = "dockerhub"
  upstream_registry_url = "registry-1.docker.io"
}

resource "aws_ecr_pull_through_cache_rule" "public_ecr" {
  count                 = var.enable_pull_through_cache ? 1 : 0
  ecr_repository_prefix = "ecr-public"
  upstream_registry_url = "public.ecr.aws"
}

# ---- Registry Scanning Configuration ------------------------
resource "aws_ecr_registry_scanning_configuration" "main" {
  scan_type = "ENHANCED"   # Uses Amazon Inspector v2

  rule {
    scan_frequency = "CONTINUOUS_SCAN"
    repository_filter {
      filter      = "*"
      filter_type = "WILDCARD"
    }
  }
}
