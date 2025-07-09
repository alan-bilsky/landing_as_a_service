variable "parameters" {
  description = "A map of SSM parameters to create."
  type = map(object({
    value     = string
    type      = optional(string, "SecureString")
    overwrite = optional(bool, false)
  }))
  default = {}
}

resource "aws_ssm_parameter" "params" {
  for_each = var.parameters

  name      = each.key
  type      = each.value.type
  value     = each.value.value
  overwrite = each.value.overwrite
  tags      = var.tags
}

output "parameter_names" {
  description = "The names of the created SSM parameters"
  value       = [for p in aws_ssm_parameter.params : p.name]
}

output "parameter_arns" {
  description = "The ARNs of the created SSM parameters, keyed by name."
  value = {
    for k, p in aws_ssm_parameter.params : k => p.arn
  }
} 