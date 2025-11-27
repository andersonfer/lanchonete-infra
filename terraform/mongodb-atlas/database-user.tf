# Gera senha aleatoria para o usuario do banco
resource "random_password" "mongodb_password" {
  length           = 24
  special          = true
  override_special = "-_"
  min_lower        = 4
  min_upper        = 4
  min_numeric      = 4
  min_special      = 2
}

# Usuario do banco de dados
resource "mongodbatlas_database_user" "pagamento" {
  project_id         = var.atlas_project_id
  username           = var.database_username
  password           = random_password.mongodb_password.result
  auth_database_name = "admin"

  # Roles - acesso apenas ao database de pagamentos
  roles {
    role_name     = "readWrite"
    database_name = var.database_name
  }

  # Escopo - apenas para este cluster
  scopes {
    name = mongodbatlas_advanced_cluster.pagamento.name
    type = "CLUSTER"
  }
}
