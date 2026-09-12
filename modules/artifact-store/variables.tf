variable "organization_name"  { type = string }
variable "environment"        { type = string }
variable "bucket_name"        { type = string }
variable "kms_key_arn"        { type = string }
variable "retention_days" {
  type    = number
  default = 30
}
variable "pipeline_role_arn"  { type = string }
variable "codebuild_role_arn" { type = string }
# variable "log_retention_days" {
#   type    = number
#   default = 365
#   description = "CloudWatch log retention period in days. Must be at least 365 to comply with CKV_AWS_338."
# }
