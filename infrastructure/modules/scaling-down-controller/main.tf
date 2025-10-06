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
  name = "lambda-scaling-down-controller-${var.env}"
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
  name        = "scaling-down-controller-sqs-policy-${var.env}"
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
          var.end_idle_task_queue_arn
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_ecs_policy" {
  name        = "scaling-down-controller-ecs-policy-${var.env}"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecs:StopTask",
          "ecs:DescribeServices",
          "ecs:UpdateService"
        ],
        "Resource": "*"
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_asg_policy" {
  name        = "scaling-down-controller-asg-policy-${var.env}"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
     {
        Effect = "Allow",
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:DescribeAutoScalingGroups"
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

resource "aws_iam_role_policy_attachment" "lambda_asg_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_asg_policy.arn
}

# ================= Lambda Function
resource "aws_lambda_function" "scaling_down_controller" {
  function_name = var.function_name
  package_type  = "Image"
  image_uri     = var.image
  role          = aws_iam_role.lambda_role.arn
  timeout       = 30

  environment {
    variables = {
      ASG_NAME = var.asg_name
    }
  }
}

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = var.end_idle_task_queue_arn
  function_name    = aws_lambda_function.scaling_down_controller.arn
  batch_size       = 10
}