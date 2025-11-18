variable "scraper_function_arn" {
  type = string
}

variable "scraper_trigger_function_name" {
  type = string
}

variable "scraper_trigger_image" {
  description = "ECR image URI to trigger scraper service"
  type        = string
}