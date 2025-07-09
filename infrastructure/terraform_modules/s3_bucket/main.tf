resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "block" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Configure the bucket for static website hosting so that
# CloudFront can serve the generated HTML pages.
resource "aws_s3_bucket_website_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  index_document {
    suffix = "index.html"
  }
}

# Create the required S3 prefixes as specified in project rules
resource "aws_s3_object" "raw_prefix" {
  bucket = aws_s3_bucket.this.id
  key    = "raw/"
  source = "/dev/null"
}

resource "aws_s3_object" "generated_prefix" {
  bucket = aws_s3_bucket.this.id
  key    = "generated/"
  source = "/dev/null"
}

resource "aws_s3_object" "public_prefix" {
  bucket = aws_s3_bucket.this.id
  key    = "public/"
  source = "/dev/null"
}
