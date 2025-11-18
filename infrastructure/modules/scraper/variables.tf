variable "scraper_function_name" {
  type = string
}

variable "scraper_image" {
  description = "ECR image URI for the scraper service"
  type        = string
}

variable "websocket_execution_arn" {
  type = string
}

variable "websocket_endpoint" {
  type = string
}

