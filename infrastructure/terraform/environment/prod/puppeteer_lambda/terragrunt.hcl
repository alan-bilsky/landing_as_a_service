locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("environment.hcl")).inputs
}

include {
  path = find_in_parent_folders()
}

dependency "iam" {
  config_path = "../iam"
}

dependency "s3_output" {
  config_path = "../s3_output"
}

dependency "cloudfront" {
  config_path = "../cloudfront"
}

terraform {
  source = "../../../../terraform_modules/puppeteer_lambda"
}

inputs = merge(local.environment_vars, {
  function_name      = "lpgen-${local.environment_vars.environment}-${local.environment_vars.region}-fetch-site"
  lambda_role_arn    = dependency.iam.outputs.lambda_role_arn
  timeout            = 60
  memory_size        = 1536
  html_output_bucket = dependency.s3_output.outputs.bucket_name
  cloudfront_domain  = dependency.cloudfront.outputs.distribution_domain_name
  environment        = local.environment_vars.environment
  region             = local.environment_vars.region
  account_id         = local.environment_vars.account_id
  tags = {
    Environment = local.environment_vars.environment
    Project     = "laas"
    Component   = "fetch_site"
  }
}) 