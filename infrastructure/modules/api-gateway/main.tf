resource "aws_apigatewayv2_api" "api" {
  name          = "voice-clone-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "generate_audio_integration" {
  api_id           = aws_apigatewayv2_api.api.id
  integration_type = "AWS_PROXY"
  integration_uri  = var.generate_audio_integration_uri
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "clone_service_integration" {
  api_id           = aws_apigatewayv2_api.api.id
  integration_type = "AWS_PROXY"
  integration_uri  = var.clone_service_integration_uri
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "list_audio_integration" {
  api_id           = aws_apigatewayv2_api.api.id
  integration_type = "AWS_PROXY"
  integration_uri  = var.list_audio_integration_uri
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "generate_audio_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /generate-audio"
  target    = "integrations/${aws_apigatewayv2_integration.generate_audio_integration.id}"
}

resource "aws_apigatewayv2_route" "clone_service_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /clone-service"
  target    = "integrations/${aws_apigatewayv2_integration.clone_service_integration.id}"
}

resource "aws_apigatewayv2_route" "list_audio_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /audio"
  target    = "integrations/${aws_apigatewayv2_integration.list_audio_integration.id}"
}

resource "aws_apigatewayv2_route" "index_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.list_audio_integration.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "allow_apigw_generate_audio" {
  statement_id  = "AllowInvokeFromApiGWGenerateAudio"
  action        = "lambda:InvokeFunction"
  function_name = var.generate_audio_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/POST/generate-audio"
}

resource "aws_lambda_permission" "allow_apigw_clone_service" {
  statement_id  = "AllowInvokeFromApiGWCloneService"
  action        = "lambda:InvokeFunction"
  function_name = var.clone_service_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/POST/clone-service"
}

resource "aws_lambda_permission" "allow_apigw_list_service" {
  statement_id  = "AllowInvokeFromApiGWListService"
  action        = "lambda:InvokeFunction"
  function_name = var.list_service_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/GET/audio"
}

resource "aws_lambda_permission" "allow_apigw_index" {
  statement_id  = "AllowInvokeFromApiGWIndexService"
  action        = "lambda:InvokeFunction"
  function_name = var.list_service_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/GET/"
}
