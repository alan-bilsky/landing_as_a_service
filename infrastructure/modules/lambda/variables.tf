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

variable "output_bucket_name" {
  type    = string
  default = ""
}
