output "lambda_invoke_arn" {
  value = aws_lambda_function.scaling_down_controller.invoke_arn
}