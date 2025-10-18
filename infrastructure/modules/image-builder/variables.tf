variable "env" {
  description = "Environment name"
  type        = string
}

variable "f5tts_image" {
  description = "Container image to pre-pull"
  type        = string
}

variable "image_builder_logs_bucket" {
  description = "S3 bucket for Image Builder logs"
  type        = string
}

variable "base_ami_id" {
  description = "Base AMI ID to build from"
  type        = string
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 100
}

variable "vpc_id" {
  type        = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "region" { 
  type=string 
}