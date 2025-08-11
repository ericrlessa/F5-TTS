terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Dead Letter Queue
resource "aws_sqs_queue" "gen_audio_dlq" {
  name = "${var.sqs_queue_name}-dlq"
}

# Main Queue with DLQ
resource "aws_sqs_queue" "gen_audio_queue" {
  name = var.sqs_queue_name

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.gen_audio_dlq.arn
    maxReceiveCount     = 3  # After 3 failed receives, message goes to DLQ
  })
}

resource "aws_sqs_queue" "gen_audio_result_dlq" {
  name = "${var.sqs_queue_name}-result-dlq"
}

resource "aws_sqs_queue" "gen_audio_result_queue" {
  name = "${var.sqs_queue_name}-result"
  visibility_timeout_seconds = 60

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.gen_audio_result_dlq.arn
    maxReceiveCount     = 3  # After 3 failed receives, message goes to DLQ
  })
}