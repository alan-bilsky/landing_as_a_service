locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("environment.hcl")).inputs
}

include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../terraform_modules/cognito"
}

inputs = merge(local.environment_vars,
  {
  user_pool_name = "laas-dev-users"
}
)