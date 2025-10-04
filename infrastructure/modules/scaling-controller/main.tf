terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ================= IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda-scaling-controller-${var.env}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Basic Lambda logging
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Custom inline policy for Lambda to send messages to SQS
resource "aws_iam_policy" "lambda_sqs_policy" {
  name        = "scaling-controller-sqs-policy-${var.env}"
  description = "Allow Lambda to send/receive messages to SQS queue"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:GetQueueAttributes",
          "sqs:DeleteMessage"
        ],
        Resource = [
          var.podcast_queue_arn,
          var.free_podcast_queue_arn,
          var.short_podcast_queue_arn,
          var.medium_podcast_queue_arn,
          var.large_podcast_queue_arn
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_ecs_policy" {
  name        = "scaling-controller-ecs-policy-${var.env}"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecs:DescribeServices",
          "ecs:UpdateService"
        ],
        "Resource": "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_sqs_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_sqs_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_ecs_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_ecs_policy.arn
}

# ================= Lambda Function
resource "aws_lambda_function" "scaling_controller" {
  function_name = var.function_name
  package_type  = "Image"
  image_uri     = var.image_name
  role          = aws_iam_role.lambda_role.arn
  timeout       = 60

  environment {
    variables = {
      FREE_PODCAST_QUEUE_URL  = var.free_podcast_queue_url
      SHORT_PODCAST_QUEUE_URL  = var.short_podcast_queue_url
      MEDIUM_PODCAST_QUEUE_URL = var.medium_podcast_queue_url
      LARGE_PODCAST_QUEUE_URL   = var.large_podcast_queue_url

      FREE_SERVICE_ECS   = var.free_service_ecs
      SHORT_SERVICE_ECS   = var.short_service_ecs
      MEDIUM_SERVICE_ECS  = var.medium_service_ecs
      LARGE_SERVICE_ECS    = var.large_service_ecs

      ECS_CLUSTER_NAME   = var.ecs_cluster_name
    }
  }
}

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = var.podcast_queue_arn
  function_name    = aws_lambda_function.scaling_controller.arn
  batch_size       = 10
}