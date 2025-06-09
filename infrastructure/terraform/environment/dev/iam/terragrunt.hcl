locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("environment.hcl")).inputs
}

include {
  path = find_in_parent_folders()
}

dependency "input_bucket" {
  config_path = "../s3_input"
}

dependency "output_bucket" {
  config_path = "../s3_output"
}

terraform {
  source = "../../../../terraform_modules/iam_roles"
}

inputs = merge(local.environment_vars,
  {
  lambda_role_name  = "laas-dev-lambda"
  input_bucket_arn  = dependency.input_bucket.outputs.bucket_arn
  output_bucket_arn = dependency.output_bucket.outputs.bucket_arn
}
)