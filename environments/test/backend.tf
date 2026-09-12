terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket              = "REPLACE-ME-test-terraform-state"
    key                 = "devsecops-pipeline/test/terraform.tfstate"
    region              = "af-south-1"
    encrypt             = true
    kms_key_id          = "alias/terraform-state-key-test"
    dynamodb_table      = "REPLACE-ME-test-terraform-state-lock"
    skip_region_validation = true
    skip_credentials_validation = true
  }
}
