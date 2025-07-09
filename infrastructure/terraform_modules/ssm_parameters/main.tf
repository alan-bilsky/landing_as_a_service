resource "aws_ssm_parameter" "bedrock_prompt" {
  name  = "/laas/bedrock/prompt"
  type  = "String"
  value = var.bedrock_prompt_template
  
  description = "Bedrock prompt template for landing page generation"
  
  tags = var.tags
}

resource "aws_ssm_parameter" "bedrock_system_prompt" {
  name  = "/laas/bedrock/system_prompt"
  type  = "String"
  value = var.bedrock_system_prompt
  
  description = "Bedrock system prompt for landing page generation"
  
  tags = var.tags
} 