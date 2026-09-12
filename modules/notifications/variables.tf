variable "organization_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "pipeline_notification_email" {
  type    = string
  default = ""
}

variable "approval_notification_email" {
  type    = string
  default = ""
}

variable "slack_webhook_secret_arn" {
  type      = string
  default   = ""
  sensitive = true
}

variable "log_retention_days" {
  type    = number
  default = 365
  description = "CloudWatch log retention period in days. Must be at least 365 to comply with CKV_AWS_338."
}

variable "account_id" {
  type = string
}

variable "lambda_subnet_ids" {
  type        = list(string)
  default     = []
  description = "Subnet IDs for Lambda VPC configuration"
}

variable "lambda_security_group_ids" {
  type        = list(string)
  default     = []
  description = "Security group IDs for Lambda VPC configuration"
}

variable "lambda_code_signing_config_arn" {
  type        = string
  default     = ""
  description = "ARN of Lambda code signing configuration"
}
