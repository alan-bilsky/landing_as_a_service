locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("environment.hcl")).inputs
}
include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../terraform_modules/s3_bucket"
}

inputs = merge(local.environment_vars,
  {
    bucket_name   = "lpgen-${local.environment_vars.environment}-${local.environment_vars.region}-input"
    force_destroy = true
  }
)

