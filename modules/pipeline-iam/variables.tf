variable "organization_name"       { type = string }
variable "environment"             { type = string }
variable "account_id"              { type = string }
variable "partition" {
  type    = string
  default = "aws"
}
variable "region"                  { type = string }
variable "artifact_bucket_name"    { type = string }
variable "kms_key_arn"             { type = string }
variable "dev_account_id"          { type = string }
variable "test_account_id"         { type = string }
variable "prod_account_id"         { type = string }
variable "codeartifact_domain_name" {
  type    = string
  default = ""
}

variable "codeartifact_enabled" {
  type    = bool
  default = true
}
