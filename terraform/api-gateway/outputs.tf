output "api_gateway_url" {
  description = "URL base do API Gateway"
  value       = "https://${aws_api_gateway_rest_api.lanchonete_api.id}.execute-api.${var.regiao}.amazonaws.com/v1"
}

output "api_gateway_endpoint" {
  description = "Endpoint do API Gateway"
  value       = "https://${aws_api_gateway_rest_api.lanchonete_api.id}.execute-api.${var.regiao}.amazonaws.com/v1"
}

output "api_gateway_id" {
  description = "ID do API Gateway"
  value       = aws_api_gateway_rest_api.lanchonete_api.id
}

output "cognito_authorizer_id" {
  description = "ID do Cognito Authorizer"
  value       = aws_api_gateway_authorizer.cognito_authorizer.id
}