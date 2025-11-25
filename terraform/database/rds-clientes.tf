# Gera senha aleatória para MySQL Clientes
# Usa apenas caracteres safe para evitar problemas de parsing/escaping
resource "random_password" "mysql_clientes" {
  length           = 20
  special          = true
  override_special = "-_+="
  min_lower        = 3
  min_upper        = 3
  min_numeric      = 3
  min_special      = 2
}

# RDS MySQL - Clientes
resource "aws_db_instance" "mysql_clientes" {
  identifier = "${local.prefix}-clientes-mysql"

  # Configurações do banco
  engine         = "mysql"
  engine_version = var.mysql_engine_version
  instance_class = var.mysql_instance_class

  # Armazenamento
  allocated_storage = var.mysql_allocated_storage
  storage_type      = "gp2"
  storage_encrypted = false

  # Credenciais
  db_name  = "clientes_db"
  username = "admin"
  password = random_password.mysql_clientes.result

  # Rede
  db_subnet_group_name   = aws_db_subnet_group.principal.name
  vpc_security_group_ids = [aws_security_group.mysql.id]
  publicly_accessible    = var.publicly_accessible

  # Configurações de manutenção
  skip_final_snapshot     = var.skip_final_snapshot
  deletion_protection     = false
  backup_retention_period = var.backup_retention_period

  # Performance e disponibilidade
  multi_az                   = false
  auto_minor_version_upgrade = true

  tags = merge(
    local.common_tags,
    {
      Name    = "${local.prefix}-clientes-mysql"
      Service = "clientes"
    }
  )
}
