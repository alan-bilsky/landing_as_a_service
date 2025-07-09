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
  default     = 30
}

variable "input_bucket_name" {
  type        = string
  description = "Name of the input S3 bucket"
}

variable "input_key" {
  type        = string
  description = "S3 key for the input file"
}

variable "output_bucket_name" {
  type        = string
  description = "Name of the output S3 bucket"
}

variable "bedrock_model_id" {
  type        = string
  description = "Bedrock model ID for image generation"
}

variable "bedrock_llm_model_id" {
  type        = string
  description = "Bedrock model ID for text generation"
  default     = "anthropic.claude-3-sonnet-20240229"
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


