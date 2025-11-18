terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_lambda_function" "scraper_trigger" {
  function_name = var.scraper_trigger_function_name
  package_type  = "Image"
  image_uri     = var.scraper_trigger_image
  role          = aws_iam_role.lambda_exec_role.arn
  timeout       = 60

  environment {
    variables = {
      SCRAPER_FUNCTION_NAME = var.scraper_function_name
      API_GATEWAY_ENDPOINT = var.websocket_endpoint
      LOG_LEVEL            = "INFO"
    }
  }
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "scraper-trigger-exec-${terraform.workspace}"
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

resource "aws_iam_role_policy" "lambda_invoke_policy" {
  name = "lambda-invoke-policy-${terraform.workspace}"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction",
          "lambda:InvokeAsync"
        ]
        Resource = var.scraper_function_arn
      }
    ]
  })
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.scraper_trigger_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.websocket_execution_arn}/*/*"
}

resource "aws_iam_role_policy" "websocket_send_message" {
  name = "websocket-send-message-${terraform.workspace}"
  role = aws_iam_role.lambda_exec_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["execute-api:ManageConnections"]
      Resource = "${var.websocket_execution_arn}/*/*"
    }]
  })
}