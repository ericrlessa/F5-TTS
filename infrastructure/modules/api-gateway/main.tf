# REST API Gateway with binary media types
resource "aws_api_gateway_rest_api" "api" {
  name        = "voice-clone-api"
  description = "Voice Clone REST API"
  
  binary_media_types = [
    "multipart/form-data",    # For form data with file uploads
    "audio/wav",              # Specifically for WAV files
    "audio/*",
    "audio/webm",          
    "application/octet-stream", # Generic binary data
    "application/x-www-form-urlencoded" # Form data
  ]
}

resource "aws_api_gateway_resource" "episodes_root" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "episodes"
}

resource "aws_api_gateway_resource" "episodes" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.episodes_root.id
  path_part   = "{id}"
}

resource "aws_api_gateway_resource" "voices_root" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "voices"
}

resource "aws_api_gateway_resource" "voices" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.voices_root.id
  path_part   = "{id}"
}


resource "aws_api_gateway_resource" "scraper" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "scraper"
}

resource "aws_api_gateway_method" "scraper_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.scraper.id
  http_method   = "POST"
  authorization = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_method" "episodes_get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.episodes.id
  http_method   = "GET"
  authorization = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_method" "episodes_post" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.episodes.id
  http_method   = "POST"
  authorization = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_method" "voices_get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.voices.id
  http_method   = "GET"
  authorization = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_method" "voices_post" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.voices.id
  http_method   = "POST"
  authorization = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_method" "voices_delete" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.voices.id
  http_method   = "DELETE"
  authorization = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "scraper_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.scraper.id
  http_method             = aws_api_gateway_method.scraper_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.scraper_integration_uri
}

resource "aws_api_gateway_integration" "episodes_integration_post" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.episodes.id
  http_method             = aws_api_gateway_method.voices_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.episodes_integration_uri
}

resource "aws_api_gateway_integration" "episodes_integration_get" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.episodes.id
  http_method             = aws_api_gateway_method.voices_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.episodes_integration_uri
}

resource "aws_api_gateway_integration" "voices_integration_get" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.voices.id
  http_method             = aws_api_gateway_method.voices_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.voices_integration_uri
}

resource "aws_api_gateway_integration" "voices_integration_post" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.voices.id
  http_method             = aws_api_gateway_method.voices_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.voices_integration_uri
}

resource "aws_api_gateway_integration" "voices_integration_delete" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.voices.id
  http_method             = aws_api_gateway_method.voices_delete.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.voices_integration_uri
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_integration.episodes_integration_get.id,
      aws_api_gateway_integration.episodes_integration_post.id,
      
      aws_api_gateway_integration.voices_integration_get.id,
      aws_api_gateway_integration.voices_integration_post.id,
      aws_api_gateway_integration.voices_integration_delete.id,

      aws_api_gateway_integration.scraper_integration.id,
    ]))
  }
  
  depends_on = [
     aws_api_gateway_integration.episodes_integration_get,
      aws_api_gateway_integration.episodes_integration_post,
      
      aws_api_gateway_integration.voices_integration_get,
      aws_api_gateway_integration.voices_integration_post,
      aws_api_gateway_integration.voices_integration_delete,

      aws_api_gateway_integration.scraper_integration,
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "stage_env" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = var.env
}

resource "aws_api_gateway_api_key" "geniuspod_api_key" {
  name = "geniuspod-api-key"
  description = "API Key for Geniuspod API"
  enabled     = true
}

resource "aws_api_gateway_usage_plan" "geniuspod_usage_plan" {
  name        = "geniuspod-usage-plan"
  description = "Usage plan for Geniuspod API"

  api_stages {
    api_id = aws_api_gateway_rest_api.api.id
    stage  = aws_api_gateway_stage.stage_env.stage_name
  }
}

resource "aws_api_gateway_usage_plan_key" "main" {
  key_id        = aws_api_gateway_api_key.geniuspod_api_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.geniuspod_usage_plan.id
}

resource "aws_lambda_permission" "allow_apigw_scraper" {
  statement_id  = "AllowInvokeFromApiGWScraper"
  action        = "lambda:InvokeFunction"
  function_name = var.scraper_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/${var.env}/POST/scraper"
}

resource "aws_lambda_permission" "allow_apigw_voices" {
  statement_id  = "AllowInvokeFromApiGWVoices"
  action        = "lambda:InvokeFunction"
  function_name = var.voices_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/${var.env}/*/voices/*"
}

resource "aws_lambda_permission" "allow_apigw_episodes" {
  statement_id  = "AllowInvokeFromApiGWEpisodes"
  action        = "lambda:InvokeFunction"
  function_name = var.episodes_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/${var.env}/*/episodes/*"
}