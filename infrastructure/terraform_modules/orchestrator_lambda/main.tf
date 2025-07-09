resource "aws_lambda_function" "orchestrator" {
  filename         = var.lambda_zip_path
  function_name    = var.function_name
  role            = var.lambda_role_arn
  handler         = "handler.handler"
  runtime         = "python3.12"
  architectures   = ["arm64"]
  timeout         = var.timeout
  memory_size     = 256

  environment {
    variables = {
      FETCH_SITE_LAMBDA_NAME  = var.fetch_site_lambda_name
      GEN_LANDING_LAMBDA_NAME = var.gen_landing_lambda_name
      INJECT_HTML_LAMBDA_NAME = var.inject_html_lambda_name
      STATUS_BUCKET           = var.status_bucket_name
    }
  }

  tags = var.tags
}

# CloudWatch Log Group is automatically created by AWS Lambda

output "lambda_function_name" {
  value = aws_lambda_function.orchestrator.function_name
}

output "lambda_function_arn" {
  value = aws_lambda_function.orchestrator.arn
}

data "aws_caller_identity" "current" {} 