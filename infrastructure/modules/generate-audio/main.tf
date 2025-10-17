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

# Policy for Batch job submission
resource "aws_iam_policy" "batch_submit_policy" {
  name        = "batch-submit-policy-${var.env}"
  description = "Policy for Lambda to submit Batch jobs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "batch:SubmitJob",
          "batch:DescribeJobs",
          "batch:ListJobs"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "batch:DescribeJobQueues",
          "batch:DescribeJobDefinitions"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "batch_submit" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.batch_submit_policy.arn
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
      JOB_QUEUE = var.batch_job_queue
      FREE_JOB_QUEUE = var.free_batch_job_queue
      JOB_DEFINITION = var.job_definition
    }
  }
}
