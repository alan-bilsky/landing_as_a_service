include {
  path = find_in_parent_folders()
}

dependency "iam" {
  config_path = "../iam"
}

terraform {
  source = "../../../modules/lambda"
}

inputs = {
  function_name   = "laas-prod-handler"
  lambda_role_arn = dependency.iam.outputs.lambda_role_arn
  timeout         = 60
}
