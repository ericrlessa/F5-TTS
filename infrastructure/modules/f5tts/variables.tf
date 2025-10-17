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

variable "free_batch_job_queue" {
  type        = string
}

variable "batch_job_queue" {
  type        = string
}

variable "job_definition" {
  type        = string
}