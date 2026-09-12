# ============================================================
# Module: codeartifact — AWS CodeArtifact Package Registry
# ============================================================
# WAF Pillars: Security, Reliability, Cost Optimization
#
# Creates a private package domain and repositories for:
#   - npm (Node.js dependencies)
#   - pip (Python packages)
#   - maven (Java artifacts)
#
# Upstream connections to public registries are proxied through
# CodeArtifact — no direct internet access from build agents.
# ============================================================

data "aws_caller_identity" "current" {}

resource "aws_codeartifact_domain" "main" {
  domain         = var.domain_name
  encryption_key = var.kms_key_arn

  tags = { Name = var.domain_name }
}

resource "aws_codeartifact_domain_permissions_policy" "main" {
  domain          = aws_codeartifact_domain.main.domain
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCodeBuildAccess"
        Effect = "Allow"
        Principal = { AWS = [var.codebuild_role_arn] }
        Action = [
          "codeartifact:DescribeDomain",
          "codeartifact:GetAuthorizationToken",
          "codeartifact:GetDomainPermissionsPolicy",
          "codeartifact:ListRepositoriesInDomain"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyNonOrganisationAccess"
        Effect = "Deny"
        Principal = "*"
        Action    = "codeartifact:*"
        Resource  = "*"
        Condition = {
          StringNotEquals = { "aws:PrincipalAccount" = var.account_id }
        }
      }
    ]
  })
}

# ---- Upstream Repositories (public proxies) -----------------
resource "aws_codeartifact_repository" "npm_upstream" {
  repository = "npm-upstream"
  domain     = aws_codeartifact_domain.main.domain
  external_connections { external_connection_name = "public:npmjs" }
  tags = { Name = "${var.domain_name}-npm-upstream" }
}

resource "aws_codeartifact_repository" "pypi_upstream" {
  repository = "pypi-upstream"
  domain     = aws_codeartifact_domain.main.domain
  external_connections { external_connection_name = "public:pypi" }
  tags = { Name = "${var.domain_name}-pypi-upstream" }
}

resource "aws_codeartifact_repository" "maven_upstream" {
  repository = "maven-upstream"
  domain     = aws_codeartifact_domain.main.domain
  external_connections { external_connection_name = "public:maven-central" }
  tags = { Name = "${var.domain_name}-maven-upstream" }
}

# ---- Internal Repository (proxies upstreams) ----------------
resource "aws_codeartifact_repository" "internal" {
  repository  = "${var.domain_name}-internal"
  domain      = aws_codeartifact_domain.main.domain
  description = "Internal packages — proxies npm, pypi, and maven upstreams."

  upstreams { repository_name = aws_codeartifact_repository.npm_upstream.repository }
  upstreams { repository_name = aws_codeartifact_repository.pypi_upstream.repository }
  upstreams { repository_name = aws_codeartifact_repository.maven_upstream.repository }

  tags = { Name = "${var.domain_name}-internal" }
}

resource "aws_codeartifact_repository_permissions_policy" "internal" {
  repository      = aws_codeartifact_repository.internal.repository
  domain          = aws_codeartifact_domain.main.domain
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowCodeBuild"
      Effect = "Allow"
      Principal = { AWS = [var.codebuild_role_arn] }
      Action = [
        "codeartifact:DescribePackageVersion", "codeartifact:DescribeRepository",
        "codeartifact:GetPackageVersionReadme", "codeartifact:GetRepositoryEndpoint",
        "codeartifact:ListPackages", "codeartifact:ListPackageVersions",
        "codeartifact:ListPackageVersionAssets", "codeartifact:ListPackageVersionDependencies",
        "codeartifact:ReadFromRepository", "codeartifact:PublishPackageVersion",
        "codeartifact:PutPackageMetadata"
      ]
      Resource = "*"
    }]
  })
}
