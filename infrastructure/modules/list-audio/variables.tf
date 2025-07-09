variable "region" { 
  type=string 
}

variable "bucket_name" {
  type    = string
}

variable "list_audio_function_name" {
  type    = string
}

variable "list_audio_handler_image" {
  type    = string
}

variable "env" {
  description = "environment"
  type        = string  
}