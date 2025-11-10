variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ca-central-1"
}

variable "account" {
  description = "AWS account to deploy resources"
  type        = string
}

locals {
  f5tts_image = "${var.account}.dkr.ecr.${var.region}.amazonaws.com/f5tts:${terraform.workspace}"
  f5tts_result_processing_image = "${var.account}.dkr.ecr.${var.region}.amazonaws.com/f5tts-result-processing:${terraform.workspace}"
  podcast_episodes_image = "${var.account}.dkr.ecr.${var.region}.amazonaws.com/podcast-episodes:${terraform.workspace}"
  voices_image = "${var.account}.dkr.ecr.${var.region}.amazonaws.com/voices:${terraform.workspace}"
  scraper_image = "${var.account}.dkr.ecr.${var.region}.amazonaws.com/scraper:${terraform.workspace}"
  bucket_name = terraform.workspace == "prod"  ?  var.bucket_name : "${var.bucket_name}-${terraform.workspace}"
}

variable "bucket_name" {
  description = "S3 bucket name used by clone-service"
  type        = string
}

variable "image_builder_logs_bucket" {
  type        = string
  default     = "geniuspod-podcast-image-builder-logs"
}

variable "sqs_queue_name" { 
  type=string 
  default="f5tts-result-events"
}

variable "ecs_instance_type" { 
  type=string 
  default="g5.xlarge" 
}

variable "podcast_episodes_function_name" {
  type = string
  default = "podcast-episodes"
}

variable "voices_function_name" {
  type    = string
  default = "voices"
}

variable "processing_result_function_name" {
  type    = string
  default = "f5tts-result-processing"
}

variable "scraper_function_name" {
  type    = string
  default = "scraper"
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

variable "job_definition" {
  type        = string
  default = "job-gpu"
}