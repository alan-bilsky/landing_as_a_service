variable "distribution_name" {
  type = string
  description = "Name of the CloudFront distribution"
}

variable "origin_bucket_name" {
  description = "Bare S3 bucket name used for bucket_policy"
  type        = string
}

variable "origin_bucket_domain_name" {
  description = "Full S3 endpoint used for CloudFront origin.domain_name"
  type        = string
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to CloudFront resources"
  default     = {}
}
