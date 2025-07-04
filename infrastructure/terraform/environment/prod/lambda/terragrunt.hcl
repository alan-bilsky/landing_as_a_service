locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("environment.hcl")).inputs
}

include {
  path = find_in_parent_folders()
}

dependency "iam" {
  config_path = "../iam"
}

dependency "input_bucket" {
  config_path = "../s3_input"
}


dependency "output_bucket" {
  config_path = "../s3_output"
}


dependency "cloudfront" {
  config_path = "../cloudfront"
}

dependency "api_gateway" {
  config_path = "../api_gateway"
}

terraform {
  before_hook "build_lambda" {
    commands = ["init", "plan", "apply"]
    execute  = ["bash", "./build/build.sh"]
  }
  source = "../../../../terraform_modules/lambda"
}

inputs = merge(local.environment_vars,
  {
  function_name   = "laas-${local.environment_vars.environment}-handler"
  lambda_role_arn = dependency.iam.outputs.lambda_role_arn
  timeout         = 60

  input_bucket_name  = dependency.input_bucket.outputs.bucket_name
  input_key          = "landing_template.html"
  output_bucket_name = dependency.output_bucket.outputs.bucket_name
  bedrock_model_id   = "amazon.titan-image-generator-v2:0"
  cloudfront_domain  = dependency.cloudfront.outputs.distribution_domain_name
  region             = local.environment_vars.region
  account_id         = tostring(local.environment_vars.account_id)
  api_gateway_id     = dependency.api_gateway.outputs.api_gateway_id
}
)