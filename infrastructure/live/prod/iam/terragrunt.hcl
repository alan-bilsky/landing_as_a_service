include {
  path = find_in_parent_folders()
}

dependency "input_bucket" {
  config_path = "../s3_input"
}

dependency "output_bucket" {
  config_path = "../s3_output"
}

terraform {
  source = "../../../modules/iam_roles"
}

inputs = {
  lambda_role_name  = "laas-prod-lambda"
  input_bucket_arn  = dependency.input_bucket.outputs.bucket_arn
  output_bucket_arn = dependency.output_bucket.outputs.bucket_arn
}
