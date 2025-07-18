variable "function_name" {
  type        = string
  description = "Name of the Lambda function"
}

variable "lambda_zip_path" {
  type        = string
  description = "Path to the Lambda function ZIP file"
}

variable "lambda_role_arn" {
  type        = string
  description = "ARN of the IAM role for the Lambda function"
}

variable "timeout" {
  type        = number
  description = "Timeout for the Lambda function in seconds"
  default     = 60
}

variable "output_bucket_name" {
  type        = string
  description = "Name of the output S3 bucket"
}

variable "bedrock_model_id" {
  type        = string
  description = "Bedrock model ID for analysis"
  default     = "anthropic.claude-3-5-sonnet-20241022-v2:0"
}

variable "cloudfront_domain" {
  type        = string
  description = "CloudFront distribution domain name"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the Lambda function"
  default     = {}
} 