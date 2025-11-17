resource "aws_apigatewayv2_api" "websocket_api" {
  name          = "Geniuspod-websocket-api"
  protocol_type = "WEBSOCKET"
  route_selection_expression = "$request.body.action"
  description   = "Scraper Websocket API"
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

resource "aws_apigatewayv2_integration" "main" {
  api_id           = aws_apigatewayv2_api.websocket_api.id
  integration_type = "AWS_PROXY"
  connection_type  = "INTERNET"
  integration_uri  = var.scraper_integration_uri
}

resource "aws_apigatewayv2_route" "connect" {
  api_id    = aws_apigatewayv2_api.websocket_api.id
  route_key = "$connect"
  target    = "integrations/${aws_apigatewayv2_integration.main.id}"
}

resource "aws_apigatewayv2_route" "scrape" {
  api_id    = aws_apigatewayv2_api.websocket_api.id
  route_key = "scrape"
  target    = "integrations/${aws_apigatewayv2_integration.main.id}"
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.scraper_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.websocket_api.execution_arn}/*"
}