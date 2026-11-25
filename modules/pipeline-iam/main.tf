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
        Sid      = "CodeBuildIntegration"
        Effect   = "Allow"
        Action   = ["codebuild:BatchGetBuilds", "codebuild:StartBuild", "codebuild:StopBuild"]
        Resource = ["arn:${var.partition}:codebuild:${var.region}:${var.account_id}:project/*"]
      },
      {
        Sid    = "CodeStarConnections"
        Effect = "Allow"
        Action = ["codeconnections:UseConnection", "codestar-connections:UseConnection"]
        Resource = [
          "arn:${var.partition}:codeconnections:${var.region}:${var.account_id}:connection/*",
          "arn:${var.partition}:codestar-connections:${var.region}:${var.account_id}:connection/*"
        ]
      },
      {
        Sid      = "SNSApproval"
        Effect   = "Allow"
        Action   = ["sns:Publish"]
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
        Sid      = "CloudWatchLogs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
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
        Sid      = "ECRAuthToken"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = ["*"]
      },
      {
        # The repository belongs to the Landing Zone (af-south-1); this role only pushes and reads images.
        Sid    = "ECRImageAccess"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage", "ecr:PutImage",
          "ecr:InitiateLayerUpload", "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload", "ecr:DescribeImages",
          "ecr:ListImages"
        ]
        Resource = [var.ecr_repository_arn]
      },
      {
        Sid      = "SecretsManagerAccess"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = ["arn:${var.partition}:secretsmanager:${var.region}:${var.account_id}:secret:${var.organization_name}/*"]
      },
      {
        Sid      = "SSMParameterAccess"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
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
        Sid       = "STSGetToken"
        Effect    = "Allow"
        Action    = ["sts:GetServiceBearerToken"]
        Resource  = ["*"]
        Condition = { StringEquals = { "sts:AWSServiceName" = "codeartifact.amazonaws.com" } }
      },
      {
        Sid      = "CrossAccountDeployDev"
        Effect   = "Allow"
        Action   = ["sts:AssumeRole"]
        Resource = ["arn:${var.partition}:iam::${var.dev_account_id}:role/${var.organization_name}-pipeline-deploy-role"]
      },
      {
        Sid      = "CrossAccountDeployTest"
        Effect   = "Allow"
        Action   = ["sts:AssumeRole"]
        Resource = ["arn:${var.partition}:iam::${var.test_account_id}:role/${var.organization_name}-pipeline-deploy-role"]
      },
      {
        Sid      = "CrossAccountDeployProd"
        Effect   = "Allow"
        Action   = ["sts:AssumeRole"]
        Resource = ["arn:${var.partition}:iam::${var.prod_account_id}:role/${var.organization_name}-pipeline-deploy-role"]
      },
      {
        Sid      = "VPCDescribe"
        Effect   = "Allow"
        Action   = ["ec2:DescribeDhcpOptions", "ec2:DescribeNetworkInterfaces", "ec2:DescribeSubnets", "ec2:DescribeSecurityGroups", "ec2:DescribeVpcs"]
        Resource = ["*"]
      },
      {
        Sid      = "VPCNetworkInterfaces"
        Effect   = "Allow"
        Action   = ["ec2:CreateNetworkInterface", "ec2:DeleteNetworkInterface", "ec2:CreateNetworkInterfacePermission"]
        Resource = ["arn:${var.partition}:ec2:${var.region}:${var.account_id}:*"]
      }
    ]
  })
}
