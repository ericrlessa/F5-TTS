variable "generate_audio_function_name" {
  type = string
}

variable "generate_audio_handler_image" {
  description = "ECR image URI for the generate-audio Lambda"
  type        = string
}

variable "bucket_name" {
  type    = string
}

variable "env" {
  description = "environment"
  type        = string  
}

variable "free_batch_job_queue" {
  type        = string
}

variable "batch_job_queue" {
  type        = string
}

variable "job_definition" {
  type        = string
}