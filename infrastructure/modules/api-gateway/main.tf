# REST API Gateway
resource "aws_api_gateway_rest_api" "api" {
  name        = "voice-clone-api"
  description = "Voice Clone REST API"
}

# Resources for each endpoint
resource "aws_api_gateway_resource" "generate_audio" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "generate-audio"
}

resource "aws_api_gateway_resource" "clone_service" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "clone-service"
}

resource "aws_api_gateway_resource" "audio" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "audio"
}

resource "aws_api_gateway_resource" "voice" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "voice"
}

# Methods for each endpoint
resource "aws_api_gateway_method" "generate_audio_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.generate_audio.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "clone_service_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.clone_service.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "list_audio_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.audio.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "index_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_rest_api.api.root_resource_id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "voice_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.voice.id
  http_method   = "GET"
  authorization = "NONE"
}

# Integrations
resource "aws_api_gateway_integration" "generate_audio_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.generate_audio.id
  http_method             = aws_api_gateway_method.generate_audio_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.generate_audio_integration_uri
}

resource "aws_api_gateway_integration" "clone_service_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.clone_service.id
  http_method             = aws_api_gateway_method.clone_service_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.clone_service_integration_uri
}

resource "aws_api_gateway_integration" "list_audio_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.audio.id
  http_method             = aws_api_gateway_method.list_audio_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.list_audio_integration_uri
}

resource "aws_api_gateway_integration" "index_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_rest_api.api.root_resource_id
  http_method             = aws_api_gateway_method.index_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.list_audio_integration_uri
}

resource "aws_api_gateway_integration" "voice_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.voice.id
  http_method             = aws_api_gateway_method.voice_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.list_audio_integration_uri
}

# Deployment
resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  depends_on = [
    aws_api_gateway_integration.generate_audio_integration,
    aws_api_gateway_integration.clone_service_integration,
    aws_api_gateway_integration.list_audio_integration,
    aws_api_gateway_integration.index_integration,
    aws_api_gateway_integration.voice_integration
  ]

  lifecycle {
    create_before_destroy = true
  }
}

# Stage
resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "prod"
}

# Lambda permissions (updated for REST API)
resource "aws_lambda_permission" "allow_apigw_generate_audio" {
  statement_id  = "AllowInvokeFromApiGWGenerateAudio"
  action        = "lambda:InvokeFunction"
  function_name = var.generate_audio_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/prod/POST/generate-audio"
}

resource "aws_lambda_permission" "allow_apigw_clone_service" {
  statement_id  = "AllowInvokeFromApiGWCloneService"
  action        = "lambda:InvokeFunction"
  function_name = var.clone_service_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/prod/POST/clone-service"
}

resource "aws_lambda_permission" "allow_apigw_list_audio" {
  statement_id  = "AllowInvokeFromApiGWListAudio"
  action        = "lambda:InvokeFunction"
  function_name = var.list_service_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/prod/GET/audio"
}

resource "aws_lambda_permission" "allow_apigw_index" {
  statement_id  = "AllowInvokeFromApiGWIndex"
  action        = "lambda:InvokeFunction"
  function_name = var.list_service_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/prod/GET/"
}

resource "aws_lambda_permission" "allow_apigw_voice" {
  statement_id  = "AllowInvokeFromApiGWVoice"
  action        = "lambda:InvokeFunction"
  function_name = var.list_service_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/prod/GET/voice"
}