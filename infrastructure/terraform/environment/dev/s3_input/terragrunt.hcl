include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules/s3_bucket"
}

inputs = {
  bucket_name   = "laas-dev-input"
  force_destroy = true
}
