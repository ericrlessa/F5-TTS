variable "processing_result_function_name" {
  type = string
}

variable "processing_result_handler_image" {
  description = "ECR image URI for the processing-result-listener Lambda"
  type        = string
}

variable "supabase_url" {
  description = "supabase url"
  type        = string
}

variable "supabase_service_key" {
  description = "supabase service key"
  type        = string
}

variable "sqs_queue_arn" {
  description = "sqs queue to trigger the lambda"
  type        = string
}
