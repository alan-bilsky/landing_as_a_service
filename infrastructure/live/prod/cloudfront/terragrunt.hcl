include {
  path = find_in_parent_folders()
}

dependency "output_bucket" {
  config_path = "../s3_output"
}

terraform {
  source = "../../../modules/cloudfront"
}

inputs = {
  distribution_name         = "laas-prod-cf"
  origin_bucket_domain_name = dependency.output_bucket.outputs.bucket_name
}
