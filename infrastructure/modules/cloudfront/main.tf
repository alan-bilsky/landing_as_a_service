resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${var.distribution_name}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  comment             = var.distribution_name
  default_root_object = "index.html"

  origin {
    domain_name              = var.origin_bucket_domain_name
    origin_id                = var.origin_bucket_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    target_origin_id       = var.origin_bucket_domain_name
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }
  }

  restrictions { geo_restriction { restriction_type = "none" } }

  viewer_certificate { cloudfront_default_certificate = true }
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "oac_read" {
  statement {
    actions = ["s3:GetObject"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    resources = ["arn:aws:s3:::${var.origin_bucket_domain_name}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [
        "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/${aws_cloudfront_origin_access_control.oac.id}"
      ]
    }
  }
}

resource "aws_s3_bucket_policy" "allow_oac" {
  bucket = var.origin_bucket_domain_name
  policy = data.aws_iam_policy_document.oac_read.json
}
