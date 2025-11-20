output "scraper_invoke_arn" {
  value = aws_lambda_function.scraper.invoke_arn
  description = "Invoke ARN of scraper"
}

output "scraper_arn" {
  value = aws_lambda_function.scraper.arn
  description = "Invoke ARN of scraper"
}