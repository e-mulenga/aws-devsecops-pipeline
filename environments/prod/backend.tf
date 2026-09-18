terraform {
  backend "s3" {
    bucket              = "REPLACE-ME-prod-terraform-state"
    key                 = "devsecops-pipeline/prod/terraform.tfstate"
    region              = "af-south-1"
    encrypt             = true
    use_lockfile        = true # Enables native S3 state locking
  }
}

terraform {
  required_version = ">= 1.5.0"
}