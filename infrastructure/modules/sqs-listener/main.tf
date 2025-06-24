terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# 🔹 Create SQS Queue
resource "aws_sqs_queue" "s3_event_queue" {
  name = var.sqs_queue_name
}

# 🔹 Allow S3 to send messages to SQS
resource "aws_sqs_queue_policy" "allow_s3" {
  queue_url = aws_sqs_queue.s3_event_queue.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowS3SendMessage",
        Effect    = "Allow",
        Principal = { Service = "s3.amazonaws.com" },
        Action    = "sqs:SendMessage",
        Resource  = aws_sqs_queue.s3_event_queue.arn,
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:s3:::${var.bucket_name}"
          }
        }
      }
    ]
  })
}

# 🔹 Create S3 Event Notification for Existing Bucket
resource "aws_s3_bucket_notification" "s3_to_sqs" {
  bucket = var.bucket_name

  queue {
    queue_arn     = aws_sqs_queue.s3_event_queue.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".txt"
  }

  depends_on = [aws_sqs_queue_policy.allow_s3]
}

output "sqs_queue_url" {
  value = aws_sqs_queue.s3_event_queue.id
}

output "sqs_queue_arn" {
  value = aws_sqs_queue.s3_event_queue.arn
}