variable "clone_service_function_name" {
  type = string
  default = "voice-clone-handler"
}

variable "region" {
  description = "AWS region to deploy resources"
  type        = string
}