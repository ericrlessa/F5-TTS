variable "clone_service_integration_uri" {
  type = string
}

variable "generate_audio_integration_uri" {
  type = string
}

variable "list_audio_integration_uri" {
  type = string
}

variable "scraper_integration_uri" {
  type = string
}

variable "generate_audio_function_name" {
  type = string
}

variable "delete_voice_function_name" {
  type = string
}

variable "delete_voice_integration_uri" {
  type = string
}

variable "clone_service_function_name" {
  type = string
}

variable "list_service_function_name" {
  type = string
}

variable "scraper_function_name" {
  type = string
}

variable "env" {
  description = "environment"
  type        = string  
}

variable "region" { 
  type=string 
}
