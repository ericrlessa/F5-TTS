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
  f5tts_result_processing_image = "${var.account}.dkr.ecr.${var.region}.amazonaws.com/f5tts-result-processing:latest"
  podcast_episodes_image = "${var.account}.dkr.ecr.${var.region}.amazonaws.com/podcast-episodes:latest"
  voices_image = "${var.account}.dkr.ecr.${var.region}.amazonaws.com/voices:latest"
  scraper_image = "${var.account}.dkr.ecr.${var.region}.amazonaws.com/scraper:latest"
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
  default="f5tts-result-events"
}

variable "ecs_instance_type" { 
  type=string 
  default="g5.xlarge" 
}

variable "ecs_cluster_name" { 
  type=string 
  default="voice-clone-cluster" 
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