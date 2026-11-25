# ============================================================
# Landing Zone consumption (source of truth).
# This stack never creates VPCs, subnets, NAT, endpoints, KMS keys, the Route 53 zone, ACM certificates, the platform SNS
# topic, logging buckets, GuardDuty, Security Hub, Inspector, ECR repositories, state buckets or the GitHub OIDC provider.
# Everything below is READ from the Landing Zone's remote state.
# ============================================================

variable "landing_zone_state_bucket" {
  description = "S3 bucket holding the Landing Zone Terraform state (Landing Zone output: terraform_state.bucket)."
  type        = string
}

variable "landing_zone_state_key" {
  description = "S3 key of the Landing Zone Terraform state (Landing Zone output: terraform_state.key)."
  type        = string
}

variable "landing_zone_state_region" {
  description = "Region of the Landing Zone state bucket (Landing Zone output: terraform_state.region)."
  type        = string
}

variable "expected_landing_zone_contract_version" {
  description = "Landing Zone contract_schema_version this stack was written against."
  type        = string
  default     = "2"
}

variable "ecr_repository_key" {
  description = "Key of the Landing Zone ecr_repository_urls map the pipeline pushes images to."
  type        = string
  default     = "shared-devsecops"
}

data "terraform_remote_state" "landing_zone" {
  backend = "s3"

  config = {
    bucket  = var.landing_zone_state_bucket
    key     = var.landing_zone_state_key
    region  = var.landing_zone_state_region
    encrypt = true
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  lz = data.terraform_remote_state.landing_zone.outputs

  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition

  name_prefix = "${var.organization_name}-${var.environment}"

  # ---- Key strategy: recorded only. Landing Zone keys are af-south-1 keys and cannot encrypt eu-west-1 resources ----
  key_strategy = try(local.lz.key_strategy, "aws-managed")

  # ---- Container registry: owned by the Landing Zone ----
  ecr_repository_url = local.lz.ecr_repository_urls[var.ecr_repository_key]
  ecr_registry       = split("/", local.ecr_repository_url)[0]
  ecr_region         = split(".", local.ecr_registry)[3]
  ecr_repository_arn = "arn:${local.partition}:ecr:${local.ecr_region}:${local.account_id}:repository/${join("/", slice(split("/", local.ecr_repository_url), 1, length(split("/", local.ecr_repository_url))))}"

  # ---- Deployment targets default to the Landing Zone account when no separate account is given ----
  dev_account_id  = coalesce(var.dev_account_id, local.account_id)
  test_account_id = coalesce(var.test_account_id, local.account_id)
  prod_account_id = coalesce(var.prod_account_id, local.account_id)
}

resource "terraform_data" "landing_zone_contract" {
  lifecycle {
    precondition {
      condition     = try(local.lz.contract_schema_version, "") == var.expected_landing_zone_contract_version
      error_message = "The Landing Zone contract_schema_version does not match expected_landing_zone_contract_version. Review the Landing Zone changelog before applying."
    }

    precondition {
      condition     = contains(keys(try(local.lz.ecr_repository_urls, {})), var.ecr_repository_key)
      error_message = "ecr_repository_key is not a key of the Landing Zone ecr_repository_urls output."
    }

    precondition {
      condition     = var.ireland_region == try(local.lz.eu_west_1.region, var.ireland_region)
      error_message = "ireland_region must equal the Landing Zone eu_west_1 region."
    }
  }
}
