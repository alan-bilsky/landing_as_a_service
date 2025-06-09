locals {
  # Region and bucket for storing Terraform state. These are parameterized so
  # dev and prod can supply different values when running Terragrunt.
  region       = get_env("TG_REGION", "us-west-2")
  state_bucket = get_env("TG_STATE_BUCKET")
  lock_table   = get_env("TG_DYNAMODB_TABLE", "terragrunt-locks")
}

# Configure remote state in S3 with DynamoDB locking.
remote_state {
  backend = "s3"
  config = {
    bucket         = local.state_bucket
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.region
    encrypt        = true
    dynamodb_table = local.lock_table
  }
}
