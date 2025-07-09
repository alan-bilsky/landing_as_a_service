resource "aws_lambda_function" "gen_landing" {
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
        INPUT_BUCKET        = var.input_bucket_name
        INPUT_KEY           = var.input_key
        OUTPUT_BUCKET       = var.output_bucket_name
        BEDROCK_MODEL_ID    = var.bedrock_model_id
        BEDROCK_LLM_MODEL_ID = var.bedrock_llm_model_id
        BEDROCK_REGION      = var.region
        CLOUDFRONT_DOMAIN   = var.cloudfront_domain
      }
    }

  tags = var.tags
}

# CloudWatch Log Group is automatically created by AWS Lambda





