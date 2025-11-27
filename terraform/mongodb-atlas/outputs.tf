output "cluster_name" {
  description = "Nome do cluster MongoDB Atlas"
  value       = mongodbatlas_advanced_cluster.pagamento.name
}

output "cluster_id" {
  description = "ID do cluster MongoDB Atlas"
  value       = mongodbatlas_advanced_cluster.pagamento.cluster_id
}

# Connection String padrao (mongodb+srv://)
output "connection_string_srv" {
  description = "Connection string SRV do MongoDB Atlas (sem credenciais)"
  value       = mongodbatlas_advanced_cluster.pagamento.connection_strings[0].standard_srv
}

# Connection String completa (para uso direto)
output "connection_string_full" {
  description = "Connection string completa com credenciais (sensivel)"
  value       = "mongodb+srv://${mongodbatlas_database_user.pagamento.username}:${random_password.mongodb_password.result}@${replace(mongodbatlas_advanced_cluster.pagamento.connection_strings[0].standard_srv, "mongodb+srv://", "")}/${var.database_name}?retryWrites=true&w=majority"
  sensitive   = true
}

output "database_name" {
  description = "Nome do database"
  value       = var.database_name
}

output "database_username" {
  description = "Usuario do banco de dados"
  value       = mongodbatlas_database_user.pagamento.username
}

output "database_password" {
  description = "Senha do banco de dados (sensivel)"
  value       = random_password.mongodb_password.result
  sensitive   = true
}

# Cluster host (extraido da connection string)
output "cluster_host" {
  description = "Host do cluster (sem protocolo)"
  value       = replace(mongodbatlas_advanced_cluster.pagamento.connection_strings[0].standard_srv, "mongodb+srv://", "")
}
