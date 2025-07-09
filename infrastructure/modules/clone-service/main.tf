terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "bucket_name" {
  description = "S3 bucket to store audio and text"
  type        = string
}

variable "clone_service_image" {
  description = "ECR image URI for the clone service"
  type        = string
}

resource "aws_lambda_function" "voice_clone_handler" {
  function_name = var.clone_service_function_name
  package_type  = "Image"
  image_uri     = var.clone_service_image
  role          = aws_iam_role.lambda_exec_role.arn
  timeout       = 60

  environment {
    variables = {
      BUCKET_NAME = var.bucket_name
    }
  }

}

resource "aws_iam_role" "lambda_exec_role" {
  name = "voice-clone-handler-exec-${var.env}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "s3_full_access" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}