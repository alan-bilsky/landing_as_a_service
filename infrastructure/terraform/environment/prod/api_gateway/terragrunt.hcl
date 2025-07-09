locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("environment.hcl")).inputs
}

include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../terraform_modules/api_gateway"
}

dependency "orchestrator_lambda" {
  config_path = "../orchestrator_lambda"
}

inputs = merge(local.environment_vars,
  {
  api_name = "lpgen-${local.environment_vars.environment}-${local.environment_vars.region}-api"
  lambda_function_name = dependency.orchestrator_lambda.outputs.lambda_function_name
  region = local.environment_vars.region
  account_id = tostring(local.environment_vars.account_id)
}
)