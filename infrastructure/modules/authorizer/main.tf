terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_lambda_function" "authorizer" {
  function_name = var.authorizer_function_name
  package_type  = "Image"
  image_uri     = var.authorizer_image
  role          = aws_iam_role.lambda_exec_role.arn
  timeout       = 5

  environment {
    variables = {      
      JWT_SECRET         = var.jwt_secret
      ISSUER_URL_JWT     = var.issuer_url_jwt
    }
  }
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "authorizer-exec-${terraform.workspace}"
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

resource "aws_lambda_permission" "api_gateway_invoke_authorizer" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.authorizer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.websocket_execution_arn}/*/*"
}