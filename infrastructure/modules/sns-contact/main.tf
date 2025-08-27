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

resource "aws_iam_user" "sns_user" {
  name = "geniuspod-sns-publisher-user"
}

data "aws_iam_policy_document" "sns_publish_policy" {
  statement {
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.my_topic.arn]
  }
}

resource "aws_iam_policy" "sns_publish_policy" {
  name   = "sns-publish-policy"
  policy = data.aws_iam_policy_document.sns_publish_policy.json
}

resource "aws_iam_user_policy_attachment" "attach_sns_policy" {
  user       = aws_iam_user.sns_user.name
  policy_arn = aws_iam_policy.sns_publish_policy.arn
}

resource "aws_iam_access_key" "sns_user_key" {
  user = aws_iam_user.sns_user.name
}

