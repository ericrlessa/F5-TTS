output "lambda_invoke_arn" {
  value = aws_lambda_function.list_audio_handler.invoke_arn
  description = "Invoke ARN of list audio Lambda"
}