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

# Provider for us-east-1 (required for CloudFront WAF)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
   tags = {
     Environment = var.environment
     Owner       = "Laas"
     Project     = "Landing as a Service"
     Provisioned = "Terragrunt"
   }
 }
}
