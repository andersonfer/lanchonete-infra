# ===== OUTPUTS - MySQL Clientes =====

output "mysql_clientes_endpoint" {
  description = "Endpoint completo do RDS MySQL Clientes"
  value       = aws_db_instance.mysql_clientes.endpoint
}

output "mysql_clientes_address" {
  description = "Endereço do RDS MySQL Clientes (sem porta)"
  value       = aws_db_instance.mysql_clientes.address
}

output "mysql_clientes_port" {
  description = "Porta do RDS MySQL Clientes"
  value       = aws_db_instance.mysql_clientes.port
}

output "mysql_clientes_database" {
  description = "Nome do banco de dados Clientes"
  value       = aws_db_instance.mysql_clientes.db_name
}

output "mysql_clientes_username" {
  description = "Usuário do banco Clientes"
  value       = aws_db_instance.mysql_clientes.username
}

output "mysql_clientes_password" {
  description = "Senha do banco Clientes (sensível)"
  value       = random_password.mysql_clientes.result
  sensitive   = true
}

# ===== OUTPUTS - MySQL Pedidos =====

output "mysql_pedidos_endpoint" {
  description = "Endpoint completo do RDS MySQL Pedidos"
  value       = aws_db_instance.mysql_pedidos.endpoint
}

output "mysql_pedidos_address" {
  description = "Endereço do RDS MySQL Pedidos (sem porta)"
  value       = aws_db_instance.mysql_pedidos.address
}

output "mysql_pedidos_port" {
  description = "Porta do RDS MySQL Pedidos"
  value       = aws_db_instance.mysql_pedidos.port
}

output "mysql_pedidos_database" {
  description = "Nome do banco de dados Pedidos"
  value       = aws_db_instance.mysql_pedidos.db_name
}

output "mysql_pedidos_username" {
  description = "Usuário do banco Pedidos"
  value       = aws_db_instance.mysql_pedidos.username
}

output "mysql_pedidos_password" {
  description = "Senha do banco Pedidos (sensível)"
  value       = random_password.mysql_pedidos.result
  sensitive   = true
}

# ===== OUTPUTS - MySQL Cozinha =====

output "mysql_cozinha_endpoint" {
  description = "Endpoint completo do RDS MySQL Cozinha"
  value       = aws_db_instance.mysql_cozinha.endpoint
}

output "mysql_cozinha_address" {
  description = "Endereço do RDS MySQL Cozinha (sem porta)"
  value       = aws_db_instance.mysql_cozinha.address
}

output "mysql_cozinha_port" {
  description = "Porta do RDS MySQL Cozinha"
  value       = aws_db_instance.mysql_cozinha.port
}

output "mysql_cozinha_database" {
  description = "Nome do banco de dados Cozinha"
  value       = aws_db_instance.mysql_cozinha.db_name
}

output "mysql_cozinha_username" {
  description = "Usuário do banco Cozinha"
  value       = aws_db_instance.mysql_cozinha.username
}

output "mysql_cozinha_password" {
  description = "Senha do banco Cozinha (sensível)"
  value       = random_password.mysql_cozinha.result
  sensitive   = true
}

# ===== OUTPUTS CONSOLIDADOS =====

output "all_endpoints" {
  description = "Todos os endpoints dos bancos RDS"
  value = {
    mysql_clientes = aws_db_instance.mysql_clientes.endpoint
    mysql_pedidos  = aws_db_instance.mysql_pedidos.endpoint
    mysql_cozinha  = aws_db_instance.mysql_cozinha.endpoint
  }
}
