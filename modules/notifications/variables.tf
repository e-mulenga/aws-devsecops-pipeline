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
  default = 90
}

variable "account_id" {
  type = string
}

variable "region" {
  type = string
}
