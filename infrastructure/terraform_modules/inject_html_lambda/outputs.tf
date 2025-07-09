output "function_name" {
  description = "Name of the inject_html Lambda function"
  value       = aws_lambda_function.inject_html.function_name
}

output "function_arn" {
  description = "ARN of the inject_html Lambda function"
  value       = aws_lambda_function.inject_html.arn
}

output "role_arn" {
  description = "ARN of the IAM role for the inject_html Lambda function"
  value       = aws_iam_role.inject_html_role.arn
} 