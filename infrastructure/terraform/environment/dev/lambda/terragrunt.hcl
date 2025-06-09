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
  source = "../../../modules/lambda"
}

inputs = {
  function_name   = "laas-dev-handler"
  lambda_role_arn = dependency.iam.outputs.lambda_role_arn
  timeout         = 60

  input_bucket_name  = dependency.input_bucket.outputs.bucket_name
  input_key          = "index.html"
  output_bucket_name = dependency.output_bucket.outputs.bucket_name
  bedrock_model_id   = "anthropic.claude-v2"
  cloudfront_domain  = dependency.cloudfront.outputs.distribution_domain_name
}
