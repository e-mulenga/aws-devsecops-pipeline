terraform {
  backend "s3" {
    bucket         = "REPLACE-ME-prod-terraform-state"
    key            = "devsecops-pipeline/prod/terraform.tfstate"
    region         = "af-south-1"
    encrypt        = true
    kms_key_id     = "alias/terraform-state-key-prod"
    dynamodb_table = "REPLACE-ME-prod-terraform-state-lock"
  }
}
