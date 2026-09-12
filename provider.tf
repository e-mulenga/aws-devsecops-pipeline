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
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }

  # Remote backend — overridden per environment in environments/<env>/backend.tf
  backend "s3" {}
}

# ---- Primary region provider (pipeline account) -------------
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "aws-devsecops-pipeline"
      ManagedBy   = "Terraform"
      Owner       = var.owner
      CostCenter  = var.cost_center
      Environment = var.environment
      Repository  = "aws-devsecops-pipeline"
      Portfolio   = "enterprise-cloud-platform"
    }
  }
}
