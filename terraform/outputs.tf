output "api_url" {
  description = "Base URL of the Hello World API"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "lambda_function_name" {
  description = "Name of the deployed Lambda function"
  value       = aws_lambda_function.hello_world.function_name
}

output "alb_url" {
  description = "HTTP URL of the ALB (FastAPI frontend)"
  value       = "http://${aws_lb.hello_world.dns_name}"
}
