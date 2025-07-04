locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("environment.hcl")).inputs
}

include {
  path = find_in_parent_folders()
}

dependency "iam" {
  config_path = "../iam"
}

dependency "api_gateway" {
  config_path = "../api_gateway"
}

terraform {
  source = "../../../../terraform_modules/puppeteer_lambda"
}

inputs = merge(local.environment_vars,
  {
    function_name   = "laas-prod-puppeteer-renderer"
    lambda_role_arn = dependency.iam.outputs.lambda_role_arn
    timeout         = 30
    region          = local.environment_vars.region
    account_id      = local.environment_vars.account_id
    api_gateway_id  = dependency.api_gateway.outputs.api_gateway_id
  }
) 