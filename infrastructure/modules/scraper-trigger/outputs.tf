output "scraper_trigger_invoke_arn" {
  value = aws_lambda_function.scraper_trigger.invoke_arn
  description = "Invoke ARN of trigger scraper"
}