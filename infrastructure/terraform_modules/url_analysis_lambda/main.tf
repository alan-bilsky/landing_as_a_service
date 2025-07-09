resource "aws_lambda_function" "url_analysis" {
  filename         = var.lambda_zip_path
  function_name    = var.function_name
  role            = var.lambda_role_arn
  handler         = "handler.handler"
  runtime         = "python3.12"
  architectures   = ["arm64"]
  timeout         = var.timeout
  memory_size     = 512  # More memory for HTML processing and AI analysis

  environment {
    variables = {
      OUTPUT_BUCKET      = var.output_bucket_name
      BEDROCK_MODEL_ID   = var.bedrock_model_id
      BEDROCK_REGION     = var.region
      CLOUDFRONT_DOMAIN  = var.cloudfront_domain
    }
  }

  tags = var.tags
}

# CloudWatch Log Group is automatically created by AWS Lambda

output "lambda_function_name" {
  description = "Name of the URL Analysis Lambda function"
  value       = aws_lambda_function.url_analysis.function_name
}

output "lambda_function_arn" {
  description = "ARN of the URL Analysis Lambda function"
  value       = aws_lambda_function.url_analysis.arn
} 