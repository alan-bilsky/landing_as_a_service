resource "aws_ecr_repository" "puppeteer_lambda" {
  name = "puppeteer-lambda-repo"
  image_scanning_configuration {
    scan_on_push = true
  }
  force_delete = true
}

resource "aws_lambda_function" "this" {
  function_name    = var.function_name
  role             = var.lambda_role_arn
  package_type     = "Image"
  image_uri        = "${aws_ecr_repository.puppeteer_lambda.repository_url}:latest"
  timeout          = var.timeout

  environment {
    variables = {
      # Add any environment variables you need
    }
  }
}

resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.region}:${var.account_id}:${var.api_gateway_id}/*/*/render"
}

output "ecr_repository_url" {
  value = aws_ecr_repository.puppeteer_lambda.repository_url
} 