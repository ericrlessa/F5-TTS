variable "generate_audio_function_name" {
  type = string
}

variable "generate_audio_handler_image" {
  description = "ECR image URI for the generate-audio Lambda"
  type        = string
}

variable "region" {
  type    = string
}

variable "bucket_name" {
  type    = string
}

variable "sqs_queue_arn" {
  type        = string
}

variable "sqs_queue_url" {
  type        = string
}