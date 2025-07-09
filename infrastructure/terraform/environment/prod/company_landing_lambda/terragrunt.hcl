locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("environment.hcl")).inputs
}

include {
  path = find_in_parent_folders()
}

dependency "iam" {
  config_path = "../iam"
}

dependency "output_bucket" {
  config_path = "../s3_output"
}

dependency "input_bucket" {
  config_path = "../s3_input"
}

dependency "cloudfront" {
  config_path = "../cloudfront"
}

terraform {
  before_hook "build_lambda" {
    commands = ["init", "plan", "apply"]
    execute  = ["bash", "./build/build.sh"]
  }
  source = "../../../../terraform_modules/company_landing_lambda"
}

inputs = merge(local.environment_vars, {
  function_name        = "lpgen-${local.environment_vars.environment}-${local.environment_vars.region}-company-landing"
  lambda_zip_path      = "${get_terragrunt_dir()}/../../../../terraform_modules/company_landing_lambda/build/lambda.zip"
  lambda_role_arn      = dependency.iam.outputs.lambda_role_arn
  timeout              = 60
  output_bucket_name   = dependency.output_bucket.outputs.bucket_name
  template_bucket_name = dependency.input_bucket.outputs.bucket_name
  template_key         = "company_landing_template.html"
  cloudfront_domain    = dependency.cloudfront.outputs.distribution_domain_name
  tags = {
    Environment = local.environment_vars.environment
    Project     = "laas"
    Component   = "company_landing"
  }
}) 