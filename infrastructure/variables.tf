variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
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
}

variable "bucket_name" {
  description = "S3 bucket name used by clone-service"
  type        = string
  default     = "voice-clone-podcast"
}

variable "sqs_queue_name" { 
  type=string 
  default="voice-clone-gen-events" 
}

variable "ecs_instance_type" { 
  type=string 
  default="t3.small" 
}

variable "ecs_cluster_name" { 
  type=string 
  default="voice-clone-cluster" 
}

variable "ecs_ami_ssm_param" {
  type = string
  default = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}