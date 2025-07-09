# WAF Web ACL with managed common rule set (must be in us-east-1)
resource "aws_wafv2_web_acl" "cloudfront_waf" {
  provider = aws.us_east_1
  name     = "${var.distribution_name}-waf"
  scope    = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.distribution_name}-CommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.distribution_name}-KnownBadInputs"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.distribution_name}-WAF"
    sampled_requests_enabled   = true
  }

  tags = var.tags
}

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
  web_acl_id          = aws_wafv2_web_acl.cloudfront_waf.arn

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

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = var.tags
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "oac_read" {
  statement {
    sid       = "AllowCloudFrontReadOnly"
    actions   = ["s3:GetObject"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    # Use the bucket *name*, not the domain name
    resources = [
      "arn:aws:s3:::${var.origin_bucket_name}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"

      # Reference your *distribution* ARN, not the OAC ID
      values   = [
        "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/${aws_cloudfront_distribution.this.id}"
      ]
    }
  }
}

resource "aws_s3_bucket_policy" "allow_oac" {
  bucket = var.origin_bucket_name
  policy = data.aws_iam_policy_document.oac_read.json
}

