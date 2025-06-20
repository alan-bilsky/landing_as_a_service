locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("environment.hcl")).inputs
}

include {
  path = find_in_parent_folders()
}

dependency "lambda" {
  config_path = "../lambda"
}

terraform {
  source = "../../../../terraform_modules/api_gateway"
}

inputs = merge(local.environment_vars,
  {
  api_name            = "laas-${local.environment}-api"
  lambda_function_arn = dependency.lambda.outputs.lambda_function_arn
}
)