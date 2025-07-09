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

variable "fetch_site_lambda_name" {
  type        = string
  description = "Name of the fetch_site Lambda function"
}

variable "gen_landing_lambda_name" {
  type        = string
  description = "Name of the gen_landing Lambda function"
}

variable "inject_html_lambda_name" {
  type        = string
  description = "Name of the inject_html Lambda function"
}

variable "url_analysis_lambda_name" {
  type        = string
  description = "Name of the url_analysis Lambda function"
}

variable "company_landing_lambda_name" {
  type        = string
  description = "Name of the company_landing Lambda function"
}

variable "status_bucket_name" {
  type        = string
  description = "Name of the S3 bucket for storing job status"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the Lambda function"
  default     = {}
}



 