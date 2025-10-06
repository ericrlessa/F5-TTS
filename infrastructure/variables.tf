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
  sqs_listener_image = "${var.account}.dkr.ecr.${var.region}.amazonaws.com/sqs-listener:latest"
  generate_audio_handler_image = "${var.account}.dkr.ecr.${var.region}.amazonaws.com/gen-audio-handler:latest"
  clone_service_image = "${var.account}.dkr.ecr.${var.region}.amazonaws.com/lambda-voice-clone:latest"
  list_audio_handler_image = "${var.account}.dkr.ecr.${var.region}.amazonaws.com/list-audio-handler:latest"
  processing_result_handler_image = "${var.account}.dkr.ecr.${var.region}.amazonaws.com/processing-result-listener:latest"
  scraper_image = "${var.account}.dkr.ecr.${var.region}.amazonaws.com/scraper:latest"
  scaling_controller_image = "${var.account}.dkr.ecr.${var.region}.amazonaws.com/scaling-controller:latest"
  scaling_down_controller_image = "${var.account}.dkr.ecr.${var.region}.amazonaws.com/scaling-down-controller:latest"
}

variable "bucket_name" {
  description = "S3 bucket name used by clone-service"
  type        = string
  default     = "geniuspod-podcast"
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

variable "ecs_ami_ssm_param" {
  type = string
  default = "/aws/service/ecs/optimized-ami/amazon-linux-2/gpu/recommended/image_id"
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

variable "free_service_ecs" {
  type        = string
  default = "free-plan-service"
}

variable "short_service_ecs" {
  type        = string
  default = "short-podcasts-service"
}

variable "medium_service_ecs" {
  type        = string  
  default = "medium-podcasts-service"
}

variable "large_service_ecs" {
  type        = string  
  default = "large-podcasts-service"
}

variable "asg_name" {
  type        = string  
  default = "f5tts-asg"
}