output "api_id" {
  description = "ID of the API Gateway"
  value       = aws_apigatewayv2_api.api.id
}

output "api_endpoint" {
  description = "Base endpoint URL for the API Gateway"
  value       = aws_apigatewayv2_api.api.api_endpoint
}

output "generate_audio_url" {
  description = "POST endpoint for generating audio"
  value       = "${aws_apigatewayv2_api.api.api_endpoint}/generate-audio"
}

output "clone_service_url" {
  description = "POST endpoint for clone service"
  value       = "${aws_apigatewayv2_api.api.api_endpoint}/clone-service"
}