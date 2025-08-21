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

output "generate_audio_url" {
  description = "POST endpoint for generating audio"
  value       = "${local.base_url}/generate-audio"
}

output "clone_service_url" {
  description = "POST endpoint for clone service"
  value       = "${local.base_url}/clone-service"
}

output "list_audio_url" {
  description = "GET endpoint for list audio service"
  value       = "${local.base_url}/audio"
}

output "index_url" {
  description = "GET endpoint for index"
  value       = local.base_url
}

output "voice_url" {
  description = "GET endpoint for voice"
  value       = "${local.base_url}/voice"
}

# Output the API key value (you'll need to retrieve this securely)
output "api_key_value" {
  description = "The value of the API key. Store this securely!"
  value       = aws_api_gateway_api_key.voice_clone_api_key.value
  sensitive   = true
}

output "api_key_id" {
  description = "The ID of the API key"
  value       = aws_api_gateway_api_key.voice_clone_api_key.id
}

output "usage_plan_id" {
  description = "The ID of the usage plan"
  value       = aws_api_gateway_usage_plan.voice_clone_usage_plan.id
}

output "api_invoke_url" {
  description = "The base URL of the API"
  value       = "https://${aws_api_gateway_rest_api.api.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_stage.stage_env.stage_name}"
}