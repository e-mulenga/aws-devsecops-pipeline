variable "organization_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "codebuild_role_arn" {
  type = string
}

variable "artifact_bucket_name" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "build_image" {
  type    = string
  default = "aws/codebuild/standard:7.0"
}

variable "build_compute_type" {
  type    = string
  default = "BUILD_GENERAL1_MEDIUM"
}

variable "build_timeout_minutes" {
  type    = number
  default = 60
}

variable "vpc_id" {
  type    = string
  default = ""
}

variable "private_subnet_ids" {
  type    = list(string)
  default = []
}

variable "security_group_ids" {
  type    = list(string)
  default = []
}

variable "log_retention_days" {
  type    = number
  default = 90
}

variable "ecr_repository_urls" {
  type    = map(string)
  default = {}
}

variable "iac_scan_enabled" {
  type    = bool
  default = true
}

variable "dependency_scan_enabled" {
  type    = bool
  default = true
}

variable "sast_failure_action" {
  type    = string
  default = "BLOCK"
}

variable "container_scan_severity" {
  type    = string
  default = "HIGH"
}

variable "codeartifact_domain" {
  type    = string
  default = ""
}

variable "codeartifact_repository" {
  type    = string
  default = ""
}

variable "dev_account_id" {
  type = string
}

variable "test_account_id" {
  type = string
}

variable "prod_account_id" {
  type = string
}
