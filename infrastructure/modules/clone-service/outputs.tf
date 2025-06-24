output "lambda_invoke_arn" {
  value = aws_lambda_function.voice_clone_handler.invoke_arn
  description = "Invoke ARN of voice clone Lambda"
}