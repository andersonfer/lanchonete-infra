output "user_pool_id" {
  description = "ID do Cognito User Pool"
  value       = aws_cognito_user_pool.lanchonete_auth.id
}

output "user_pool_client_id" {
  description = "ID do Cognito User Pool Client"
  value       = aws_cognito_user_pool_client.lanchonete_auth_client.id
}

output "user_pool_arn" {
  description = "ARN do Cognito User Pool"
  value       = aws_cognito_user_pool.lanchonete_auth.arn
}

output "user_pool_domain" {
  description = "Domínio do Cognito User Pool"
  value       = aws_cognito_user_pool_domain.lanchonete_auth_domain.domain
}

output "user_pool_endpoint" {
  description = "Endpoint do Cognito User Pool"
  value       = aws_cognito_user_pool.lanchonete_auth.endpoint
}