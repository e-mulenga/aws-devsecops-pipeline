# ============================================================
# AWS DevSecOps Pipeline — Provider Configuration
# ============================================================
# Portfolio Standard: provider.tf contains BOTH the terraform{}
# block (required_version + required_providers) AND all provider
# configurations. No separate versions.tf is used.
#
# Portfolio Position: 3 of 6
# Depends on: aws-enterprise-landing-zone (account structure, KMS)
#             terraform-enterprise-module-library (reusable modules)
# Consumed by: aws-cloud-security-operations-center
#              aws-secure-eks-platform
# ============================================================

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }

  # Partial backend: bucket and region come from environments/<env>/backend.hcl, the key from scripts/tf.sh.
  backend "s3" {}
}

locals {
  default_tags = {
    Project     = "aws-devsecops-pipeline"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
}

# Cape Town (default): only the Landing Zone remote state is read from here. Nothing in this stack is created in af-south-1.
provider "aws" {
  region = var.primary_region

  default_tags {
    tags = local.default_tags
  }
}

# Ireland: AWS CodeConnections (the GitHub source connection) and AWS CodeArtifact are not offered in af-south-1
# (docs/regional-availability.md, checked 2026-11-25). A pipeline can only use a connection from its own Region, so
# CodePipeline, CodeBuild, the artifact bucket, CodeArtifact and the alerting topics all run in eu-west-1 through this alias.
provider "aws" {
  alias  = "ireland"
  region = var.ireland_region

  default_tags {
    tags = local.default_tags
  }
}
