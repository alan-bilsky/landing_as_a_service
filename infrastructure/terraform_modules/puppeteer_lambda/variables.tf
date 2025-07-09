variable "function_name" {
  type        = string
  description = "Name of the Lambda function"
}

variable "lambda_role_arn" {
  type        = string
  description = "ARN of the IAM role for the Lambda function"
}

variable "timeout" {
  type        = number
  description = "Timeout for the Lambda function in seconds"
  default     = 30
}

variable "memory_size" {
  type        = number
  description = "Memory size for the Lambda function in MB"
  default     = 128
}

variable "html_output_bucket" {
  type        = string
  description = "S3 bucket name for HTML output"
}

variable "cloudfront_domain" {
  type        = string
  description = "CloudFront distribution domain name for serving images"
  default     = ""
}

# environment and region variables are defined in global_variables.tf

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the Lambda function"
  default     = {}
} 