terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda-audio-result-role-${var.env}"
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

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_sqs_policy" {
  name = "lambda-sqs-audio-result-${var.env}"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ]
      Resource = var.sqs_queue_arn
    }]
  })
}

resource "aws_lambda_function" "processing_result_handler" {
  function_name = var.processing_result_function_name
  package_type  = "Image"
  image_uri     = var.processing_result_handler_image
  role          = aws_iam_role.lambda_role.arn
  timeout       = 60

  environment {
    variables = {
      SUPABASE_URL         = var.supabase_url,
      SUPABASE_SERVICE_KEY = var.supabase_service_key      
    }
  }
}

# Event source mapping to trigger Lambda from SQS
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = var.sqs_queue_arn
  function_name    = aws_lambda_function.processing_result_handler.arn
  batch_size       = 10
  enabled          = true
}
