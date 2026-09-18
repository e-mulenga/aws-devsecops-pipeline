variable "organization_name"  { 
  type = string 
}

variable "environment" { 
  type = string 
}

variable "bucket_name" { 
  type = string 
}

variable "kms_key_arn" { 
  type = string 
}

variable "retention_days" {
  type    = number
  default = 30
}

variable "pipeline_role_arn" { 
  type = string 
}

variable "codebuild_role_arn" { 
  type = string 
}

variable "log_retention_days" {
  type    = number
  default = 365
  description = "CloudWatch log retention period in days. Must be at least 365 to comply with CKV_AWS_338."
}

variable "replication_role_arn" {
  description = "IAM role ARN that S3 assumes to replicate objects to the destination bucket. Must have s3:ReplicateObject, s3:ReplicateDelete, and KMS permissions."
  type        = string
}

variable "replication_destination_bucket_arn" {
  description = "ARN of the destination S3 bucket (secondary region) for artifacts replication."
  type        = string
}

variable "replication_destination_logs_bucket_arn" {
  description = "ARN of the destination S3 bucket (secondary region) for access logs replication."
  type        = string
}

variable "replication_destination_kms_key_arn" {
  description = "ARN of the KMS key in the destination region used to encrypt replicated objects."
  type        = string
}
