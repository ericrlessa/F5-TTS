variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ca-central-1"
}

variable "env" {
  description = "environment"
  type        = string  
}

variable "account" {
  description = "AWS account to deploy resources"
  type        = string
}

locals {
  f5tts_image = "${var.account}.dkr.ecr.${var.region}.amazonaws.com/f5tts:latest"
  sqs_listener_image = "${var.account}.dkr.ecr.${var.region}.amazonaws.com/batch-job:latest"
  generate_audio_handler_image = "${var.account}.dkr.ecr.${var.region}.amazonaws.com/gen-audio-handler:latest"
  clone_service_image = "${var.account}.dkr.ecr.${var.region}.amazonaws.com/lambda-voice-clone:latest"
  list_audio_handler_image = "${var.account}.dkr.ecr.${var.region}.amazonaws.com/list-audio-handler:latest"
  processing_result_handler_image = "${var.account}.dkr.ecr.${var.region}.amazonaws.com/processing-result-listener:latest"
  scraper_image = "${var.account}.dkr.ecr.${var.region}.amazonaws.com/scraper:latest"
  scaling_controller_image = "${var.account}.dkr.ecr.${var.region}.amazonaws.com/scaling-controller:latest"
  scaling_down_controller_image = "${var.account}.dkr.ecr.${var.region}.amazonaws.com/scaling-down-controller:latest"
  voice_delete_image = "${var.account}.dkr.ecr.${var.region}.amazonaws.com/voice-delete:latest"
}

variable "bucket_name" {
  description = "S3 bucket name used by clone-service"
  type        = string
  default     = "geniuspod-podcast"
}

variable "image_builder_logs_bucket" {
  type        = string
  default     = "geniuspod-podcast-image-builder-logs"
}

variable "sqs_queue_name" { 
  type=string 
  default="generate-audio-events"
}

variable "ecs_instance_type" { 
  type=string 
  default="g5.xlarge" 
}

variable "ecs_cluster_name" { 
  type=string 
  default="voice-clone-cluster" 
}

variable "scaling_conroller_function_name" {
  type = string
  default = "scaling_conroller"
}

variable "generate_audio_function_name" {
  type = string
  default = "gen-audio"
}

variable "clone_service_function_name" {
  type = string
  default = "voice-clone-handler"
}

variable "list_audio_function_name" {
  type    = string
  default = "list-audio"
}

variable "delete_voice_function_name" {
  type    = string
  default = "voice-delete"
}

variable "processing_result_function_name" {
  type    = string
  default = "processing-result-audio"
}

variable "scraper_function_name" {
  type    = string
  default = "scraper"
}

variable "scaling_down_controller_function_name" {
  type    = string
  default = "scaling-down-controller"
}

variable "supabase_url" {
  type    = string
}

variable "supabase_service_key" {
  type    = string
}

variable "sns_emails" {
  description = "List of email addresses to subscribe to the SNS topic"
  type        = list(string)
}

variable "domain_name" {
  type        = string
}

variable "origin_id" {
  type        = string
}

variable "origin_domain_name" {
  type        = string
}

variable "free_batch_job_queue" {
  type        = string
  default = "free-batch-job-queue"
}

variable "batch_job_queue" {
  type        = string
  default = "batch-job-queue"
}

variable "job_definition" {
  type        = string
  default = "job-gpu"
}