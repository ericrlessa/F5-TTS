output "sns_topic_arn" {
  value = aws_sns_topic.my_topic.arn
}

output "sns_user_access_key_id" {
  value       = aws_iam_access_key.sns_user_key.id
  description = "Access Key ID for the SNS IAM user"
}

output "sns_user_secret_access_key" {
  value       = aws_iam_access_key.sns_user_key.secret
  description = "Secret Access Key for the SNS IAM user"
  sensitive   = true
}
