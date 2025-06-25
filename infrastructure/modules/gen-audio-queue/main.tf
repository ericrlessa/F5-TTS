terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# 🔹 Create SQS Queue
resource "aws_sqs_queue" "gen_audio_queue" {
  name = var.sqs_queue_name
}