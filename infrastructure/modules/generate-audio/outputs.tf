output "lambda_invoke_arn" {
  value = aws_lambda_function.gen_audio_handler.invoke_arn
  description = "Invoke ARN of gen audio Lambda"
}