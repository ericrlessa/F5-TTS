output "websocket_url" {
  value = "${aws_apigatewayv2_api.websocket_api.api_endpoint}/${aws_apigatewayv2_stage.stage.name}"
}

output "websocket_api_id" {
  value = "${aws_apigatewayv2_api.websocket_api.id}"
}

output "execution_arn" {
  value = "${aws_apigatewayv2_api.websocket_api.execution_arn}"
}
 