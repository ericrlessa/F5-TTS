output "authorizer_invoke_arn" {
  value = aws_lambda_function.authorizer.invoke_arn
  description = "Invoke ARN of authorizer"
}

output "authorizer_arn" {
  value = aws_lambda_function.authorizer.arn
  description = "Invoke ARN of authorizer"
}
