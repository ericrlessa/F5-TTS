variable "env" {
  description = "environment"
  type        = string  
}

variable "region" { 
  type=string 
}

variable "voices_integration_uri" {
  type = string
}

variable "episodes_integration_uri" {
  type = string
}

variable "scraper_integration_uri" {
  type = string
}

variable "voices_function_name" {
  type = string
}

variable "episodes_function_name" {
  type = string
}

variable "scraper_function_name" {
  type = string
}