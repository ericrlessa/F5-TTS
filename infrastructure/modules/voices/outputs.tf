output "lambda_invoke_arn" {
  value = aws_lambda_function.voices_lambda.invoke_arn
  description = "Invoke ARN of list audio Lambda"
}