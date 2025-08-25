terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_sns_topic" "my_topic" {
  name = "geniuspod-contact-sns-topic"
}

resource "aws_sns_topic_subscription" "email_subscriptions" {
  for_each  = toset(var.sns_emails)
  topic_arn = aws_sns_topic.my_topic.arn
  protocol  = "email"
  endpoint  = each.value
}
