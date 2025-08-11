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
  name = "lambda-gen-text-role-${var.env}"
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

# Full access to S3 (you may want to limit this to just Get/Put if needed)
resource "aws_iam_role_policy_attachment" "lambda_s3" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# Custom inline policy for Lambda to send messages to SQS
resource "aws_iam_policy" "lambda_sqs_policy" {
  name        = "lambda-sqs-send-policy-${var.env}"
  description = "Allow Lambda to send messages to SQS queue"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "sqs:SendMessage"
        ],
        Resource = var.sqs_queue_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_sqs_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_sqs_policy.arn
}

# ================= Lambda Function
resource "aws_lambda_function" "gen_audio_handler" {
  function_name = var.generate_audio_function_name
  package_type  = "Image"
  image_uri     = var.generate_audio_handler_image
  role          = aws_iam_role.lambda_role.arn
  timeout       = 60

  environment {
    variables = {
      BUCKET_NAME    = var.bucket_name
      SQS_REC_QUEUE_URL  = var.sqs_queue_url
    }
  }
}
