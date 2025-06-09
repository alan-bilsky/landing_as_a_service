variable "function_name" {
  type = string
}

variable "lambda_role_arn" {
  type = string
}

variable "timeout" {
  type    = number
  default = 60
}

variable "input_bucket_name" {
  type = string
}

variable "input_key" {
  type = string
}

variable "output_bucket_name" {
  type = string
}

variable "bedrock_model_id" {
  type = string
}

variable "cloudfront_domain" {
  type    = string
  default = ""
}
