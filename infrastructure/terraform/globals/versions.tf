terraform {
  required_version = "~> 1.1"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.2.0"
      configuration_aliases = [aws.us_east_1]
    }
  }
}