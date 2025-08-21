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

# Methods for each endpoint - UPDATED WITH API KEY REQUIRED
resource "aws_api_gateway_method" "generate_audio_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.generate_audio.id
  http_method   = "POST"
  authorization = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_method" "clone_service_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.clone_service.id
  http_method   = "POST"
  authorization = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_method" "list_audio_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.audio.id
  http_method   = "GET"
  authorization = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_method" "index_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_rest_api.api.root_resource_id
  http_method   = "GET"
  authorization = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_method" "voice_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.voice.id
  http_method   = "GET"
  authorization = "NONE"
  api_key_required = true
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

# Stage - MUST BE DEFINED BEFORE USAGE PLAN
resource "aws_api_gateway_stage" "stage_env" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = var.env
}

# API Key and Usage Plan - MOVED AFTER STAGE DEFINITION
resource "aws_api_gateway_api_key" "voice_clone_api_key" {
  name = "voice-clone-api-key"
  description = "API Key for Voice Clone API"
  enabled     = true
}

resource "aws_api_gateway_usage_plan" "voice_clone_usage_plan" {
  name        = "voice-clone-usage-plan"
  description = "Usage plan for Voice Clone API"

  api_stages {
    api_id = aws_api_gateway_rest_api.api.id
    stage  = aws_api_gateway_stage.stage_env.stage_name  # ✅ Now stage is defined
  }

  quota_settings {
    limit  = 1000  # Monthly quota
    offset = 0
    period = "MONTH"
  }

  throttle_settings {
    burst_limit = 10   # Maximum number of requests per second over time period
    rate_limit  = 5    # Steady-state rate limit
  }
}

resource "aws_api_gateway_usage_plan_key" "main" {
  key_id        = aws_api_gateway_api_key.voice_clone_api_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.voice_clone_usage_plan.id
}

# Lambda permissions (updated for REST API)
resource "aws_lambda_permission" "allow_apigw_generate_audio" {
  statement_id  = "AllowInvokeFromApiGWGenerateAudio"
  action        = "lambda:InvokeFunction"
  function_name = var.generate_audio_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/${var.env}/POST/generate-audio"
}

resource "aws_lambda_permission" "allow_apigw_clone_service" {
  statement_id  = "AllowInvokeFromApiGWCloneService"
  action        = "lambda:InvokeFunction"
  function_name = var.clone_service_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/${var.env}/POST/clone-service"
}

resource "aws_lambda_permission" "allow_apigw_list_audio" {
  statement_id  = "AllowInvokeFromApiGWListAudio"
  action        = "lambda:InvokeFunction"
  function_name = var.list_service_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/${var.env}/GET/audio"
}

resource "aws_lambda_permission" "allow_apigw_index" {
  statement_id  = "AllowInvokeFromApiGWIndex"
  action        = "lambda:InvokeFunction"
  function_name = var.list_service_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/${var.env}/GET/"
}

resource "aws_lambda_permission" "allow_apigw_voice" {
  statement_id  = "AllowInvokeFromApiGWVoice"
  action        = "lambda:InvokeFunction"
  function_name = var.list_service_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/${var.env}/GET/voice"
}

# Output the API key value (you'll need to retrieve this securely)
output "api_key_value" {
  description = "The value of the API key. Store this securely!"
  value       = aws_api_gateway_api_key.voice_clone_api_key.value
  sensitive   = true
}

output "api_key_id" {
  description = "The ID of the API key"
  value       = aws_api_gateway_api_key.voice_clone_api_key.id
}

output "usage_plan_id" {
  description = "The ID of the usage plan"
  value       = aws_api_gateway_usage_plan.voice_clone_usage_plan.id
}

output "api_invoke_url" {
  description = "The base URL of the API"
  value       = "https://${aws_api_gateway_rest_api.api.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_stage.stage_env.stage_name}"
}