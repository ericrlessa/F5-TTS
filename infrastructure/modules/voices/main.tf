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
  name = "voices-role-${var.env}"
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

# ================= Lambda Function
resource "aws_lambda_function" "voices_lambda" {
  function_name = var.voices_function_name
  package_type  = "Image"
  image_uri     = var.voices_image_uri
  role          = aws_iam_role.lambda_role.arn
  timeout       = 60

  environment {
    variables = {
      BUCKET_NAME    = var.bucket_name
    }
  }
}
