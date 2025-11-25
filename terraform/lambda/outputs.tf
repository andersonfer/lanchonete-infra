output "lambda_function_name" {
  description = "Nome da função Lambda"
  value       = aws_lambda_function.auth_lambda.function_name
}

output "lambda_function_arn" {
  description = "ARN da função Lambda"
  value       = aws_lambda_function.auth_lambda.arn
}

output "lambda_invoke_arn" {
  description = "ARN de invocação da Lambda para API Gateway"
  value       = aws_lambda_function.auth_lambda.invoke_arn
}