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

resource "aws_sqs_queue" "short_podcasts_dlq" {
  name = "short-podcasts-dlq"
}

resource "aws_sqs_queue" "short_podcasts" {
  name = "short-podcasts"
  visibility_timeout_seconds = 60

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.short_podcasts_dlq.arn
    maxReceiveCount     = 3  # After 3 failed receives, message goes to DLQ
  })
}

resource "aws_sqs_queue" "medium_podcasts_dlq" {
  name = "medium-podcasts-dlq"
}

resource "aws_sqs_queue" "medium_podcasts" {
  name = "medium-podcasts"
  visibility_timeout_seconds = 60

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.medium_podcasts_dlq.arn
    maxReceiveCount     = 3  # After 3 failed receives, message goes to DLQ
  })
}

resource "aws_sqs_queue" "large_podcasts_dlq" {
  name = "large-podcasts-dlq"
}

resource "aws_sqs_queue" "large_podcasts" {
  name = "large-podcasts"
  visibility_timeout_seconds = 60

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.large_podcasts_dlq.arn
    maxReceiveCount     = 3  # After 3 failed receives, message goes to DLQ
  })
}


resource "aws_sqs_queue" "free_dlq" {
  name = "free-dlq"
}

resource "aws_sqs_queue" "free" {
  name = "free"
  visibility_timeout_seconds = 60

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.free_dlq.arn
    maxReceiveCount     = 3  # After 3 failed receives, message goes to DLQ
  })
}

resource "aws_sqs_queue" "end_idle_task_dlq" {
  name = "end-idle-task-dlq"
}

resource "aws_sqs_queue" "end_idle_task" {
  name = "end-idle-task"
  visibility_timeout_seconds = 60

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.free_dlq.arn
    maxReceiveCount     = 3  # After 3 failed receives, message goes to DLQ
  })
}
