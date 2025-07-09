resource "aws_lambda_function" "inject_html" {
  filename         = var.lambda_zip_path
  function_name    = var.function_name
  role            = aws_iam_role.inject_html_role.arn
  handler         = "handler.handler"
  runtime         = "python3.12"
  architectures   = ["arm64"]
  timeout         = 60
  memory_size     = 256

  environment {
    variables = {
      OUTPUT_BUCKET      = var.output_bucket_name
      CLOUDFRONT_DOMAIN  = var.cloudfront_domain
    }
  }

  tags = var.tags
}

resource "aws_iam_role" "inject_html_role" {
  name = "${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "inject_html_basic" {
  role       = aws_iam_role.inject_html_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "inject_html_s3" {
  name = "${var.function_name}-s3-policy"
  role = aws_iam_role.inject_html_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${var.output_bucket_arn}/raw/*",
          "${var.output_bucket_arn}/generated/*",
          "${var.output_bucket_arn}/public/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "inject_html_cloudfront" {
  name = "${var.function_name}-cloudfront-policy"
  role = aws_iam_role.inject_html_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudfront:ListDistributions",
          "cloudfront:CreateInvalidation"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "inject_html_bedrock" {
  name = "${var.function_name}-bedrock-policy"
  role = aws_iam_role.inject_html_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["bedrock:InvokeModel"]
        Resource = [
          "arn:aws:bedrock:*::foundation-model/amazon.titan-image-generator-v2:0"
        ]
      }
    ]
  })
}

# CloudWatch Log Group is automatically created by AWS Lambda 