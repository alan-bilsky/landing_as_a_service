locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("environment.hcl")).inputs
}

include {
  path = find_in_parent_folders()
}

dependency "iam" {
  config_path = "../iam"
}

dependency "puppeteer_lambda" {
  config_path = "../puppeteer_lambda"
}

dependency "lambda" {
  config_path = "../lambda"
}

dependency "inject_html_lambda" {
  config_path = "../inject_html_lambda"
}

dependency "url_analysis_lambda" {
  config_path = "../url_analysis_lambda"
}

dependency "company_landing_lambda" {
  config_path = "../company_landing_lambda"
}

dependency "output_bucket" {
  config_path = "../s3_output"
}

terraform {
  source = "../../../../terraform_modules/orchestrator_lambda"
}

inputs = merge(local.environment_vars, {
  function_name             = "lpgen-${local.environment_vars.environment}-${local.environment_vars.region}-orchestrator"
  lambda_zip_path           = "${get_terragrunt_dir()}/../../../../terraform_modules/orchestrator_lambda/build/lambda.zip"
  lambda_role_arn           = dependency.iam.outputs.lambda_role_arn
  timeout                   = 120
  fetch_site_lambda_name    = dependency.puppeteer_lambda.outputs.lambda_function_name
  gen_landing_lambda_name   = dependency.lambda.outputs.lambda_function_name
  inject_html_lambda_name   = dependency.inject_html_lambda.outputs.function_name
  url_analysis_lambda_name  = dependency.url_analysis_lambda.outputs.lambda_function_name
  company_landing_lambda_name = dependency.company_landing_lambda.outputs.lambda_function_name
  status_bucket_name        = dependency.output_bucket.outputs.bucket_name
  region                    = local.environment_vars.region
  tags = {
    Environment = local.environment_vars.environment
    Project     = "laas"
    Component   = "orchestrator"
  }
}) 