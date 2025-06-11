data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/build"       # <-- see below
  output_path = "${path.module}/lambda.zip"
  excludes    = ["*.tf", "*.md"]             # optional filters
}


resource "aws_lambda_function" "this" {
  depends_on       = [null_resource.build_lambda]
  function_name    = var.function_name
  role             = var.lambda_role_arn
  handler          = "handler.handler"
  runtime          = "python3.9"
  filename         = "${path.module}/lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda.zip")
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

resource "null_resource" "build_lambda" {
  # run on every plan/apply
  triggers = {
    rebuild = "${timestamp()}"
  }

  provisioner "local-exec" {
    command     = "bash ${path.module}/build/build.sh"
    working_dir = "${path.module}"
  }

}
