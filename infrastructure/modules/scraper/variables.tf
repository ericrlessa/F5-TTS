variable "scraper_function_name" {
  type = string
}

variable "scraper_image" {
  description = "ECR image URI for the scraper service"
  type        = string
}

variable "region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "env" {
  description = "environment"
  type        = string  
}