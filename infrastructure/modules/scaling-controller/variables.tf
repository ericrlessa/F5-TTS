variable "function_name" {
  type = string
}

variable "image_name" {
  type        = string
}

variable "podcast_queue_arn" {
  type        = string
}

variable "podcast_queue_url" {
  type        = string
}

variable "short_podcast_queue_arn" {
  type        = string
}

variable "short_podcast_queue_url" {
  type        = string
}

variable "medium_podcast_queue_arn" {
  type        = string
}

variable "medium_podcast_queue_url" {
  type        = string
}

variable "large_podcast_queue_arn" {
  type        = string
}

variable "large_podcast_queue_url" {
  type        = string
}

variable "free_podcast_queue_arn" {
  type        = string
}

variable "free_podcast_queue_url" {
  type        = string
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

variable "ecs_cluster_name" {
  type        = string
}