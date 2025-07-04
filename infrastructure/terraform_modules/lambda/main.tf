resource "aws_lambda_function" "this" {
  function_name    = var.function_name
  role             = var.lambda_role_arn
  handler          = "handler.handler"
  runtime          = "python3.9"
  filename         = "${path.module}/build/lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/build/lambda.zip")
  timeout          = var.timeout

  environment {
    variables = {
      INPUT_BUCKET       = var.input_bucket_name
      INPUT_KEY          = var.input_key
      OUTPUT_BUCKET      = var.output_bucket_name
      BEDROCK_MODEL_ID   = var.bedrock_model_id
      CLOUDFRONT_DOMAIN  = var.cloudfront_domain
    }
  }
}



resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.region}:${var.account_id}:${var.api_gateway_id}/*/*/chat-landing"
}
