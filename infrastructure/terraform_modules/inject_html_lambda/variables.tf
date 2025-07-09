variable "lambda_zip_path" {
  type        = string
  description = "Path to the Lambda function ZIP file"
}

variable "function_name" {
  type        = string
  description = "Name of the Lambda function"
}

variable "output_bucket_name" {
  type        = string
  description = "Name of the S3 bucket for output"
}

variable "output_bucket_arn" {
  type        = string
  description = "ARN of the S3 bucket for output"
}

variable "cloudfront_domain" {
  type        = string
  description = "CloudFront domain for serving generated pages"
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the Lambda function"
  default     = {}
} 