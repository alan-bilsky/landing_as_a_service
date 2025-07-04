variable "function_name" {
  type = string
}

variable "lambda_role_arn" {
  type = string
}

variable "timeout" {
  type    = number
  default = 30
}

variable "api_gateway_id" {
  type = string
} 