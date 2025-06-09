data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/handler.py"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  role          = var.lambda_role_arn
  handler       = "handler.handler"
  runtime       = "python3.9"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
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
