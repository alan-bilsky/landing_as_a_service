resource "aws_apigatewayv2_api" "this" {
  name          = var.api_name
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["OPTIONS", "POST"]
    allow_headers = ["Content-Type", "Authorization"]
  }
}

data "aws_lambda_function" "target" {
  function_name = var.lambda_function_name
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                = aws_apigatewayv2_api.this.id
  integration_type      = "AWS_PROXY"
  integration_uri       = data.aws_lambda_function.target.arn
  integration_method    = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "post" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "chat_landing" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /chat-landing"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_cloudwatch_log_group" "apigw_access_logs" {
  name = "/aws/apigateway/laas-prod-api-access-logs"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_resource_policy" "apigw_access" {
  policy_name = "APIGatewayAccessPolicy"
  policy_document = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": { "Service": "apigateway.amazonaws.com" },
        "Action": "logs:PutLogEvents",
        "Resource": "arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws/apigateway/laas-prod-api-access-logs:*"
      }
    ]
  })
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigw_access_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
    })
  }
}
