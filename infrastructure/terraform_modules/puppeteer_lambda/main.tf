resource "aws_ecr_repository" "puppeteer_lambda" {
  name = "puppeteer-lambda-repo"
  image_scanning_configuration {
    scan_on_push = true
  }
  force_delete = true
}

# Use existing S3 bucket (created by s3_output module)
data "aws_s3_bucket" "html_output" {
  bucket = var.html_output_bucket
}

locals {
  effective_html_output_bucket = var.html_output_bucket
  account_id = data.aws_caller_identity.current.account_id
  ecr_image_uri = "${aws_ecr_repository.puppeteer_lambda.repository_url}:latest"
  # Force replacement when code changes
  code_hash = filesha256("${path.module}/build/index.js")
}

data "aws_caller_identity" "current" {}

resource "aws_lambda_function" "fetch_site" {
  function_name    = var.function_name
  role            = var.lambda_role_arn
  package_type    = "Image"
  image_uri       = local.ecr_image_uri
  timeout         = var.timeout
  memory_size     = var.memory_size

  environment {
    variables = {
      HTML_OUTPUT_BUCKET = var.html_output_bucket
      CLOUDFRONT_DOMAIN  = var.cloudfront_domain
      CODE_HASH = local.code_hash # Forces update when code changes
    }
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "fetch_site_logs" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 30
}

resource "aws_iam_policy" "puppeteer_lambda_s3_write" {
  name        = "${var.function_name}-s3-write"
  description = "Allow Puppeteer Lambda to write HTML to S3 output bucket"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${data.aws_s3_bucket.html_output.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "puppeteer_lambda_s3_write_attach" {
  role       = element(reverse(split("/", var.lambda_role_arn)), 0)
  policy_arn = aws_iam_policy.puppeteer_lambda_s3_write.arn
} 