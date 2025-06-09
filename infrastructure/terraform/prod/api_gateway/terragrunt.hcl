include {
  path = find_in_parent_folders()
}

dependency "lambda" {
  config_path = "../lambda"
}

terraform {
  source = "../../../modules/api_gateway"
}

inputs = {
  api_name            = "laas-prod-api"
  lambda_function_arn = dependency.lambda.outputs.lambda_function_arn
}
