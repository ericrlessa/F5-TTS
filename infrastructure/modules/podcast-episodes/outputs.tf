output "lambda_invoke_arn" {
  value = aws_lambda_function.podcast_episodes.invoke_arn
  description = "Invoke ARN of episodes Lambda"
}