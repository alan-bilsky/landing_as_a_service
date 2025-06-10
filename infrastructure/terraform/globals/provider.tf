provider "aws" {
  region = var.region

  default_tags {
   tags = {
     Environment = var.environment
     Owner       = "Laas"
     Project     = "Landing as a Service"
     Provisioned = "Terragrunt"
   }
 }
}
