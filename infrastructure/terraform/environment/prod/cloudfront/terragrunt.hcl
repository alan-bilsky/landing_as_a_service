locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("environment.hcl")).inputs
}

include {
  path = find_in_parent_folders()
}

dependency "output_bucket" {
  config_path = "../s3_output"
}

terraform {
  source = "../../../../terraform_modules/cloudfront"
}

inputs = merge(local.environment_vars, {
  distribution_name           = "laas-${local.environment_vars.environment}-cf"
  origin_bucket_name          = dependency.output_bucket.outputs.bucket_name
  origin_bucket_domain_name   = "${dependency.output_bucket.outputs.bucket_name}.s3.amazonaws.com"
})
