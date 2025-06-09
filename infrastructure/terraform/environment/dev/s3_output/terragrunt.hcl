locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("environment.hcl")).inputs
}
include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules/s3_bucket"
}

inputs = {
  bucket_name   = "laas-dev-output"
  force_destroy = true
}
