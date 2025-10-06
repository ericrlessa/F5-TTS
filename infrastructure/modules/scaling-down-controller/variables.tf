variable "function_name" {
  type = string
}

variable "image" {
  type        = string
}

variable "end_idle_task_queue_arn" {
  type        = string
}

variable "env" {
  description = "environment"
  type        = string  
}

variable "asg_name" {
  type        = string
}