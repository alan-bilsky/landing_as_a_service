include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules/s3_bucket"
}

inputs = {
  bucket_name   = "laas-prod-output"
  force_destroy = true
}
