# Teracloud main terragrunt variables
locals {
  environment = get_env("ENV")
  environment_vars  = read_terragrunt_config("${get_parent_terragrunt_dir()}/environment/${local.environment}/environment.hcl")
}


remote_state {
    backend = "s3"
    generate = {
        path = "backend.tf"
        if_exists = "overwrite_terragrunt"
    } 
    config = {
        bucket         = "terraform-states-teracloud-laas-${local.environment}-us-west-2"
        key            = "laas/${basename(get_terragrunt_dir())}.tfstate"
        region         = "us-west-2"
        encrypt        = true
        dynamodb_table = "terraform-locks-teracloud-laas-${local.environment}"
        skip_bucket_versioning = false
    }
}

generate "provider" {
  path      = "global_provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = file("globals/provider.tf")
}

generate "global_variables" {
  path      = "global_variables.tf"
  if_exists = "overwrite_terragrunt"
  contents  = file("globals/variables.tf")
}

generate "versions" {
  path              = "versions.tf"
  if_exists         = "skip" # allow stacks to override
  disable_signature = "true"
  contents          = file("globals/versions.tf")
}
