data "aws_iam_policy_document" "assume_role_lambda" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = var.lambda_role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role_lambda.json

}

resource "aws_iam_role_policy" "lambda_policy" {
  name   = "${var.lambda_role_name}-policy"
  role   = aws_iam_role.lambda_role.id
  policy = data.aws_iam_policy_document.lambda_policy.json
}

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
  }

  statement {
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${var.input_bucket_arn}/*", "${var.output_bucket_arn}/*"]
  }

  statement {
    actions   = ["bedrock:InvokeModel"]
    resources = [
      "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-*",
      "arn:aws:bedrock:*::foundation-model/stability.stable-diffusion-xl-v1",
      "arn:aws:bedrock:*::foundation-model/amazon.titan-image-generator-v1",
      "arn:aws:bedrock:*::foundation-model/amazon.titan-image-generator-v2:0"
    ]
  }

  statement {
    actions   = ["lambda:InvokeFunction"]
    resources = ["arn:aws:lambda:*:*:function:lpgen-*"]
  }

  statement {
    actions   = ["s3:PutObject", "s3:GetObject"]
    resources = ["${var.output_bucket_arn}/status/*"]
  }

  statement {
    actions   = ["ssm:GetParameter"]
    resources = [
      "arn:aws:ssm:*:*:parameter/laas/bedrock/prompt",
      "arn:aws:ssm:*:*:parameter/laas/bedrock/system_prompt"
    ]
  }
}
