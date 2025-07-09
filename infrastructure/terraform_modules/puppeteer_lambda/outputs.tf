output "lambda_function_name" {
  description = "Name of the fetch_site Lambda function"
  value       = aws_lambda_function.fetch_site.function_name
}

output "lambda_function_arn" {
  description = "ARN of the fetch_site Lambda function"
  value       = aws_lambda_function.fetch_site.arn
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.puppeteer_lambda.repository_url
}

output "html_output_bucket" {
  value = data.aws_s3_bucket.html_output.bucket
  description = "The S3 bucket used for output HTML."
} 