include {
  path = find_in_parent_folders()
}

dependency "iam" {
  config_path = "../iam"
}

dependency "output_bucket" {
  config_path = "../s3_output"
}

terraform {
  source = "../../../modules/lambda"
}

inputs = {
  function_name   = "laas-dev-handler"
  lambda_role_arn = dependency.iam.outputs.lambda_role_arn
  timeout         = 60
  output_bucket_name = dependency.output_bucket.outputs.bucket_name
}
