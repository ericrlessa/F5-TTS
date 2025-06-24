variable "region" {
  type    = string
}

variable "sqs_queue_name" {
  description = "The name of the SQS queue that receives events from S3"
  type        = string
}

variable "bucket_name" {
  type    = string
}