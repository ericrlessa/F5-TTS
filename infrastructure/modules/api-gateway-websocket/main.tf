resource "aws_apigatewayv2_api" "websocket_api" {
  name                       = "Geniuspod-websocket-api-${terraform.workspace}"
  protocol_type              = "WEBSOCKET"
  route_selection_expression = "$request.body.action"
  description                = "Scraper Websocket API"
}

resource "aws_apigatewayv2_stage" "stage" {
  api_id      = aws_apigatewayv2_api.websocket_api.id
  name        = terraform.workspace
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 100
    throttling_rate_limit  = 50
  }
}

# Lambda authorizer for WebSocket connections
resource "aws_apigatewayv2_authorizer" "websocket_authorizer" {
  api_id           = aws_apigatewayv2_api.websocket_api.id
  authorizer_type  = "REQUEST"
  authorizer_uri   = var.websocket_authorizer_lambda_uri
  identity_sources = [
    "route.request.querystring.token"
  ]
  name             = "websocket-connect-authorizer-${terraform.workspace}"
}

resource "aws_apigatewayv2_integration" "main" {
  api_id           = aws_apigatewayv2_api.websocket_api.id
  integration_type = "AWS_PROXY"
  connection_type  = "INTERNET"
  integration_uri  = var.scraper_integration_uri
}

# $connect route now uses the authorizer
resource "aws_apigatewayv2_route" "connect" {
  api_id             = aws_apigatewayv2_api.websocket_api.id
  route_key          = "$connect"
  authorization_type = "CUSTOM"
  authorizer_id      = aws_apigatewayv2_authorizer.websocket_authorizer.id
  target             = "integrations/${aws_apigatewayv2_integration.main.id}"
}

resource "aws_apigatewayv2_route" "scrape" {
  api_id    = aws_apigatewayv2_api.websocket_api.id
  route_key = "scrape"
  target    = "integrations/${aws_apigatewayv2_integration.main.id}"
}