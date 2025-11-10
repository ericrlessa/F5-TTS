terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_sqs_queue" "gen_audio_result_dlq" {
  name = "${var.sqs_queue_name}-result-dlq-${terraform.workspace}"
}

resource "aws_sqs_queue" "gen_audio_result_queue" {
  name = "${var.sqs_queue_name}-result-${terraform.workspace}"
  visibility_timeout_seconds = 60

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.gen_audio_result_dlq.arn
    maxReceiveCount     = 3  # After 3 failed receives, message goes to DLQ
  })
}