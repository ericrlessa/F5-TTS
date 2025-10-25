variable "delete_voice_function_name" {
  type = string
}

variable "region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "env" {
  description = "environment"
  type        = string  
}

variable "voice_delete_image" {
  description = "ECR image URI for the voice delete service"
  type        = string
}

variable "bucket_name" {
  description = "S3 bucket to store audio and text"
  type        = string
}