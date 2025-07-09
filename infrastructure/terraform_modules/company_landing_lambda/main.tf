resource "aws_lambda_function" "company_landing" {
  filename         = var.lambda_zip_path
  function_name    = var.function_name
  role            = var.lambda_role_arn
  handler         = "handler.handler"
  runtime         = "python3.12"
  architectures   = ["arm64"]
  timeout         = var.timeout
  memory_size     = 512  # More memory for HTML processing

  environment {
    variables = {
      OUTPUT_BUCKET      = var.output_bucket_name
      TEMPLATE_BUCKET    = var.template_bucket_name
      TEMPLATE_KEY       = var.template_key
      CLOUDFRONT_DOMAIN  = var.cloudfront_domain
    }
  }

  tags = var.tags
}

# CloudWatch Log Group is automatically created by AWS Lambda

output "lambda_function_name" {
  description = "Name of the Company Landing Lambda function"
  value       = aws_lambda_function.company_landing.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Company Landing Lambda function"
  value       = aws_lambda_function.company_landing.arn
} 