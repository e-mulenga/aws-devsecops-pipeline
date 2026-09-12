variable "organization_name"       { type = string }
variable "environment"             { type = string }
variable "repository_names"        { type = list(string) }
variable "kms_key_arn"             { type = string }
variable "scan_on_push" {
  type    = bool
  default = true
}

variable "image_retention_count" {
  type    = number
  default = 30
}

variable "codebuild_role_arn" {
  type = string
}

variable "cross_account_ids" {
  type    = list(string)
  default = []
}

variable "enable_pull_through_cache" {
  type    = bool
  default = true
}
