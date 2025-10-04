output "lambda_invoke_arn" {
  value = aws_lambda_function.scaling_controller.invoke_arn
}