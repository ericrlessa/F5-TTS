locals {
  base_url = "https://${aws_api_gateway_rest_api.api.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_stage.stage_env.stage_name}"
}

output "api_id" {
  description = "ID of the API Gateway"
  value       = aws_api_gateway_rest_api.api.id
}

output "api_endpoint" {
  description = "Base endpoint URL for the API Gateway"
  value       = local.base_url
}

output "api_key_value" {
  description = "The value of the API key. Store this securely!"
  value       = aws_api_gateway_api_key.geniuspod_api_key.value
  sensitive   = true
}

output "api_key_id" {
  description = "The ID of the API key"
  value       = aws_api_gateway_api_key.geniuspod_api_key.id
}

output "usage_plan_id" {
  description = "The ID of the usage plan"
  value       = aws_api_gateway_usage_plan.geniuspod_usage_plan.id
}

output "api_invoke_url" {
  description = "The base URL of the API"
  value       = "https://${aws_api_gateway_rest_api.api.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_stage.stage_env.stage_name}"
}