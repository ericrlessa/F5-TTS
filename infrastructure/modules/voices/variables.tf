variable "region" { 
  type=string 
}

variable "bucket_name" {
  type    = string
}

variable "voices_function_name" {
  type    = string
}

variable "voices_image_uri" {
  type    = string
}

variable "env" {
  description = "environment"
  type        = string  
}