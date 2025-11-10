variable "podcast_episodes_function_name" {
  type = string
}

variable "podcast_episodes_image" {
  description = "ECR image URI for the podcast episodes Lambda"
  type        = string
}

variable "bucket_name" {
  type    = string
}

variable "job_definition" {
  type        = string
}