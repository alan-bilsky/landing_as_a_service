locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("environment.hcl")).inputs
}

include {
  path = find_in_parent_folders()
}

dependency "s3_output" {
  config_path = "../s3_output"
}

dependency "cloudfront" {
  config_path = "../cloudfront"
}

terraform {
  source = "../../../../terraform_modules/inject_html_lambda"
}

inputs = merge(local.environment_vars, {
  function_name        = "lpgen-${local.environment_vars.environment}-${local.environment_vars.region}-inject-html"
  lambda_zip_path      = "${get_terragrunt_dir()}/../../../../terraform_modules/inject_html_lambda/build/lambda.zip"
  output_bucket_name   = dependency.s3_output.outputs.bucket_name
  output_bucket_arn    = dependency.s3_output.outputs.bucket_arn
  cloudfront_domain    = dependency.cloudfront.outputs.distribution_domain_name
  tags = {
    Environment = local.environment_vars.environment
    Project     = "laas"
    Component   = "inject_html"
  }
}) 