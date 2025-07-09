output "bedrock_prompt_parameter_name" {
  description = "Name of the Bedrock prompt SSM parameter"
  value       = aws_ssm_parameter.bedrock_prompt.name
}

output "bedrock_system_prompt_parameter_name" {
  description = "Name of the Bedrock system prompt SSM parameter"
  value       = aws_ssm_parameter.bedrock_system_prompt.name
}

output "bedrock_prompt_parameter_arn" {
  description = "ARN of the Bedrock prompt SSM parameter"
  value       = aws_ssm_parameter.bedrock_prompt.arn
}

output "bedrock_system_prompt_parameter_arn" {
  description = "ARN of the Bedrock system prompt SSM parameter"
  value       = aws_ssm_parameter.bedrock_system_prompt.arn
} 