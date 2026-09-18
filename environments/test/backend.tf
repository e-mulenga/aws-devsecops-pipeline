terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket              = "REPLACE-ME-test-terraform-state"
    key                 = "devsecops-pipeline/test/terraform.tfstate"
    region              = "af-south-1"
    encrypt             = true
    use_lockfile        = true # Enables native S3 state locking
    skip_region_validation = true
    skip_credentials_validation = true
  }
}
