variable "region" { 
  type=string 
}

variable "sqs_result_queue_url" {
  type        = string
}

variable "sqs_result_queue_arn" {
  type        = string
}

variable "ecs_instance_type" { 
  type=string 
}

variable "ecs_cluster_name" { 
  type=string 
}

variable "ecs_ami_ssm_param" {
  type = string
}

variable "f5tts_image" {
  type = string
}

variable "sqs_listener_image" {
  type = string
}

variable "bucket_name" {
  type    = string
}

variable "vpc_id" {}

variable "private_subnet_ids" {
  type = list(string)
}

variable "env" {
  description = "environment"
  type        = string  
}

variable "free_service_ecs" {
  type        = string  
}

variable "short_service_ecs" {
  type        = string  
}

variable "medium_service_ecs" {
  type        = string  
}

variable "large_service_ecs" {
  type        = string  
}

variable "sqs_short_podcasts_url" {
   type        = string  
}

variable "sqs_medium_podcasts_url" {
  type        = string  
}

variable "sqs_large_podcasts_url" {
  type        = string  
}

variable "sqs_free_podcasts_url" {
  type        = string  
}

variable "sqs_short_podcasts_arn" {
   type        = string  
}

variable "sqs_medium_podcasts_arn" {
  type        = string  
}

variable "sqs_large_podcasts_arn" {
  type        = string  
}

variable "sqs_free_podcasts_arn" {
  type        = string  
}
