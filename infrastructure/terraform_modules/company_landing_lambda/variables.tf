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

variable "template_bucket_name" {
  type        = string
  description = "Name of the S3 bucket containing the landing page template"
}

variable "template_key" {
  type        = string
  description = "S3 key for the landing page template"
  default     = "company_landing_template.html"
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