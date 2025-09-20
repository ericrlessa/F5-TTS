output "api_endpoint" {
  description = "Base endpoint URL for the API Gateway"
  value       = module.api_gateway.api_endpoint
}

output "sns_user_access_key_id" {
  description = "Access Key ID for the SNS IAM user"
  value       = module.sns_contact.sns_user_access_key_id
}

output "sns_user_secret_access_key" {
  description = "Secret Access Key for the SNS IAM user"
  value       = module.sns_contact.sns_user_secret_access_key
  sensitive   = true
}

output "sns_topic_arn" {
  value = module.sns_contact.sns_topic_arn
}

output "api_key_value" {
  description = "The value of the API key. Store this securely!"
  value       = module.api_gateway.api_key_value
  sensitive   = true
}

output "api_key_id" {
  description = "The ID of the API key"
  value       = module.api_gateway.api_key_id
}

output "gen_audio_sqs_queue_url" {
  value = module.gen_audio_queue.sqs_queue_url
}

output "gen_audio_sqs_queue_url_dlq" {
  value = module.gen_audio_queue.sqs_queue_url_dlq
}