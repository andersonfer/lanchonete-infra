# Variáveis consolidadas para bancos gerenciados

variable "regiao_aws" {
  description = "Região AWS para deploy"
  type        = string
  default     = "us-east-1"
}

variable "nome_projeto" {
  description = "Nome do projeto"
  type        = string
  default     = "lanchonete"
}

# Configurações MySQL
variable "mysql_engine_version" {
  description = "Versão do MySQL"
  type        = string
  default     = "8.0"
}

variable "mysql_instance_class" {
  description = "Classe da instância MySQL"
  type        = string
  default     = "db.t3.micro"
}

variable "mysql_allocated_storage" {
  description = "Storage alocado para MySQL (GB)"
  type        = number
  default     = 20
}

# Configurações DocumentDB
variable "docdb_engine_version" {
  description = "Versão do DocumentDB"
  type        = string
  default     = "5.0"
}

variable "docdb_instance_class" {
  description = "Classe da instância DocumentDB"
  type        = string
  default     = "db.t3.medium"
}

# Configurações de rede
variable "publicly_accessible" {
  description = "Se os bancos devem ser públicos"
  type        = bool
  default     = false
}

# Configurações de backup
variable "backup_retention_period" {
  description = "Período de retenção de backup (dias)"
  type        = number
  default     = 1
}

variable "skip_final_snapshot" {
  description = "Pular snapshot final ao deletar"
  type        = bool
  default     = true
}

# Tags comuns
locals {
  prefix = var.nome_projeto

  common_tags = {
    Projeto   = var.nome_projeto
    ManagedBy = "terraform"
  }
}
