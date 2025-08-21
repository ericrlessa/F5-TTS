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