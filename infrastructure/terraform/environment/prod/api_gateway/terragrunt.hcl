locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("environment.hcl")).inputs
}

include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../terraform_modules/api_gateway"
}

inputs = merge(local.environment_vars,
  {
  api_name = "laas-${local.environment_vars.environment}-api"
  lambda_function_name = "laas-${local.environment_vars.environment}-handler"
}
)