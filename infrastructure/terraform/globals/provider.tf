provider "aws" {
  region = "us-west-2"

  default_tags {
   tags = {
     Environment = var.environment
     Owner       = "Laas"
     Project     = "Landing as a Service"
     Provisioned = "Terragrunt"
   }
 }
}