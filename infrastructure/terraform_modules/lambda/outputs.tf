output "lambda_function_name" {
  description = "Name of the gen_landing Lambda function"
  value       = aws_lambda_function.gen_landing.function_name
}

output "lambda_function_arn" {
  description = "ARN of the gen_landing Lambda function"
  value       = aws_lambda_function.gen_landing.arn
}
