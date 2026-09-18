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

variable "pipeline_role_arn" { 
  type = string 
}

variable "artifact_bucket_name" { 
  type = string 
}

variable "kms_key_arn" { 
  type = string 
}

variable "source_provider" {
  type    = string
  default = "CodeStarSourceConnection"
}

variable "github_connection_arn" {
  type    = string
  default = ""
}

variable "repository_name" { 
  type = string 
}

variable "branch_name" {
  type    = string
  default = "main"
}

variable "secret_scan_project_name" { 
  type = string 
}

variable "sast_project_name" { 
  type = string 
}

variable "build_project_name" { 
  type = string 
}

variable "container_scan_project_name" { 
  type = string 
}

variable "iac_scan_project_name" { 
  type = string 
}

variable "sbom_project_name" { 
  type = string 
}

variable "integration_test_project_name" { 
  type = string 
}

variable "dast_project_name" { 
  type = string 
}

variable "deploy_dev_project_name" { 
  type = string 
}

variable "deploy_test_project_name" { 
  type = string 
}

variable "deploy_prod_project_name" { 
  type = string 
}

variable "approval_sns_topic_arn" { 
  type = string 
}

variable "require_test_approval" {
  type    = bool
  default = true
}

variable "require_prod_approval" {
  type    = bool
  default = true
}

variable "sast_enabled" {
  type    = bool
  default = true
}

variable "dast_enabled" {
  type    = bool
  default = true
}

variable "sbom_enabled" {
  type    = bool
  default = true
}

variable "iac_scan_enabled" {
  type    = bool
  default = true
}
