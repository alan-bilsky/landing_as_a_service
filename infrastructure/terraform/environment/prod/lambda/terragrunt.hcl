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

terraform {
  before_hook "build_lambda" {
    commands = ["init", "plan", "apply"]
    execute  = ["bash", "./build/build.sh"]
  }
  source = "../../../../terraform_modules/lambda"
}

inputs = merge(local.environment_vars, {
  function_name      = "lpgen-${local.environment_vars.environment}-${local.environment_vars.region}-gen-landing"
  lambda_zip_path    = "${get_terragrunt_dir()}/../../../../terraform_modules/lambda/build/lambda.zip"
  lambda_role_arn    = dependency.iam.outputs.lambda_role_arn
  timeout            = 60
  input_bucket_name  = dependency.input_bucket.outputs.bucket_name
  input_key          = "landing_template.html"
  output_bucket_name = dependency.output_bucket.outputs.bucket_name
  bedrock_model_id   = "anthropic.claude-3-5-sonnet-20241022-v2:0"
  bedrock_llm_model_id = "anthropic.claude-3-5-sonnet-20241022-v2:0"
  cloudfront_domain  = dependency.cloudfront.outputs.distribution_domain_name
  region             = local.environment_vars.region
  account_id         = tostring(local.environment_vars.account_id)
  tags = {
    Environment = local.environment_vars.environment
    Project     = "laas"
    Component   = "gen_landing"
  }
})
