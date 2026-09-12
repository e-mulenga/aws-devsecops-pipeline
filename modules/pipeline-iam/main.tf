# ============================================================
# Module: pipeline-iam — IAM Roles for DevSecOps Pipeline
# ============================================================
# WAF Pillars: Security, Operational Excellence
#
# Creates least-privilege IAM roles for:
#   - CodePipeline orchestration role
#   - CodeBuild execution role (all build projects)
#   - Cross-account deployment roles in dev/test/prod
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

//data "aws_caller_identity" "current" {}
//data "aws_region" "current" {}

data "aws_iam_policy_document" "codepipeline_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "codebuild_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

# ---- CodePipeline Role --------------------------------------
resource "aws_iam_role" "codepipeline" {
  name               = "${var.organization_name}-${var.environment}-codepipeline-role"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assume.json
  tags               = { Name = "${var.organization_name}-${var.environment}-codepipeline-role" }
}

resource "aws_iam_role_policy" "codepipeline" {
  name = "codepipeline-permissions"
  role = aws_iam_role.codepipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ArtifactStore"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:GetObjectVersion", "s3:GetBucketVersioning",
          "s3:PutObject", "s3:ListBucket"]
        Resource = [
          "arn:${var.partition}:s3:::${var.artifact_bucket_name}",
          "arn:${var.partition}:s3:::${var.artifact_bucket_name}/*"
        ]
      },
      {
        Sid      = "KMSArtifactEncryption"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:DescribeKey", "kms:GenerateDataKey"]
        Resource = [var.kms_key_arn]
      },
      {
        Sid    = "CodeBuildIntegration"
        Effect = "Allow"
        Action = ["codebuild:BatchGetBuilds", "codebuild:StartBuild", "codebuild:StopBuild"]
        Resource = ["arn:${var.partition}:codebuild:${var.region}:${var.account_id}:project/*"]
      },
      {
        Sid    = "CodeStarConnections"
        Effect = "Allow"
        Action = ["codestar-connections:UseConnection"]
        Resource = ["arn:${var.partition}:codestar-connections:${var.region}:${var.account_id}:connection/*"]
      },
      {
        Sid    = "SNSApproval"
        Effect = "Allow"
        Action = ["sns:Publish"]
        Resource = ["arn:${var.partition}:sns:${var.region}:${var.account_id}:${var.organization_name}-${var.environment}-*"]
      },
      {
        Sid    = "IAMPassRole"
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = [
          "arn:${var.partition}:iam::${var.account_id}:role/${var.organization_name}-${var.environment}-codebuild-role",
          "arn:${var.partition}:iam::${var.account_id}:role/${var.organization_name}-${var.environment}-cloudformation-role"
        ]
        Condition = {
          StringEqualsIfExists = {
            "iam:PassedToService" = [
              "cloudformation.amazonaws.com",
              "codebuild.amazonaws.com"
            ]
          }
        }
      },
      {
        Sid    = "CodeDeployIntegration"
        Effect = "Allow"
        Action = [
          "codedeploy:CreateDeployment", "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig", "codedeploy:GetApplicationRevision",
          "codedeploy:RegisterApplicationRevision"
        ]
        Resource = ["arn:${var.partition}:codedeploy:${var.region}:${var.account_id}:application/*"]
      }
    ]
  })
}

# ---- CodeBuild Role -----------------------------------------
resource "aws_iam_role" "codebuild" {
  name               = "${var.organization_name}-${var.environment}-codebuild-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume.json
  tags               = { Name = "${var.organization_name}-${var.environment}-codebuild-role" }
}

resource "aws_iam_role_policy" "codebuild" {
  name = "codebuild-permissions"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = ["arn:${var.partition}:logs:${var.region}:${var.account_id}:log-group:/aws/codebuild/*"]
      },
      {
        Sid    = "S3ArtifactAccess"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject", "s3:ListBucket"]
        Resource = [
          "arn:${var.partition}:s3:::${var.artifact_bucket_name}",
          "arn:${var.partition}:s3:::${var.artifact_bucket_name}/*"
        ]
      },
      {
        Sid      = "KMSAccess"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:DescribeKey", "kms:GenerateDataKey", "kms:Encrypt"]
        Resource = [var.kms_key_arn]
      },
      {
        Sid    = "ECRAccess"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage", "ecr:PutImage",
          "ecr:InitiateLayerUpload", "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload", "ecr:DescribeImages",
          "ecr:DescribeRepositories", "ecr:ListImages",
          "ecr:StartImageScan", "ecr:DescribeImageScanFindings"
        ]
        Resource = ["arn:${var.partition}:ecr:${var.region}:${var.account_id}:repository/${var.organization_name}/*"]
      },
      {
        Sid    = "SecretsManagerAccess"
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = ["arn:${var.partition}:secretsmanager:${var.region}:${var.account_id}:secret:${var.organization_name}/*"]
      },
      {
        Sid    = "SSMParameterAccess"
        Effect = "Allow"
        Action = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
        Resource = ["arn:${var.partition}:ssm:${var.region}:${var.account_id}:parameter/${var.organization_name}/*"]
      },
      {
        Sid    = "CodeArtifactAccess"
        Effect = "Allow"
        Action = [
          "codeartifact:GetAuthorizationToken", "codeartifact:GetRepositoryEndpoint",
          "codeartifact:ReadFromRepository", "codeartifact:PublishPackageVersion"
        ]
        Resource = var.codeartifact_enabled ? [
          "arn:${var.partition}:codeartifact:${var.region}:${var.account_id}:domain/${var.codeartifact_domain_name}",
          "arn:${var.partition}:codeartifact:${var.region}:${var.account_id}:repository/${var.codeartifact_domain_name}/*"
        ] : ["arn:${var.partition}:codeartifact:${var.region}:${var.account_id}:*"]
      },
      {
        Sid    = "STSGetToken"
        Effect = "Allow"
        Action = ["sts:GetServiceBearerToken"]
        Resource = ["*"]
        Condition = { StringEquals = { "sts:AWSServiceName" = "codeartifact.amazonaws.com" } }
      },
      {
        Sid    = "CrossAccountDeployDev"
        Effect = "Allow"
        Action = ["sts:AssumeRole"]
        Resource = ["arn:${var.partition}:iam::${var.dev_account_id}:role/${var.organization_name}-pipeline-deploy-role"]
      },
      {
        Sid    = "CrossAccountDeployTest"
        Effect = "Allow"
        Action = ["sts:AssumeRole"]
        Resource = ["arn:${var.partition}:iam::${var.test_account_id}:role/${var.organization_name}-pipeline-deploy-role"]
      },
      {
        Sid    = "CrossAccountDeployProd"
        Effect = "Allow"
        Action = ["sts:AssumeRole"]
        Resource = ["arn:${var.partition}:iam::${var.prod_account_id}:role/${var.organization_name}-pipeline-deploy-role"]
      },
      {
        Sid    = "VPCAccess"
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface", "ec2:DescribeDhcpOptions",
          "ec2:DescribeNetworkInterfaces", "ec2:DeleteNetworkInterface",
          "ec2:DescribeSubnets", "ec2:DescribeSecurityGroups", "ec2:DescribeVpcs",
          "ec2:CreateNetworkInterfacePermission"
        ]
        Resource = ["arn:${var.partition}:ec2:${var.region}:${var.account_id}:network-interface/*"]
      },
      {
        Sid    = "SecurityHubFindings"
        Effect = "Allow"
        Action = ["securityhub:BatchImportFindings"]
        Resource = ["arn:${var.partition}:securityhub:${var.region}:${var.account_id}:hub/default"]
      },
      {
        Sid    = "InspectorScanResults"
        Effect = "Allow"
        Action = ["inspector2:ListFindings", "inspector2:GetFindingsReport"]
        Resource = ["arn:${var.partition}:inspector2:${var.region}:${var.account_id}:resource/*"]
      }
    ]
  })
}

# ---- Managed Policy Attachments -----------------------------
resource "aws_iam_role_policy_attachment" "codebuild_cloudwatch" {
  role       = aws_iam_role.codebuild.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}
