variable "atlas_project_id" {
  description = "MongoDB Atlas Project ID"
  type        = string
}

variable "cluster_name" {
  description = "Nome do cluster MongoDB Atlas"
  type        = string
  default     = "pagamento-cluster"
}

variable "database_name" {
  description = "Nome do database"
  type        = string
  default     = "pagamentos"
}

variable "database_username" {
  description = "Usuario do banco de dados"
  type        = string
  default     = "pagamento_user"
}

variable "atlas_region" {
  description = "Regiao do Atlas (formato Atlas, nao AWS)"
  type        = string
  default     = "US_EAST_1"
}

variable "nome_projeto" {
  description = "Nome do projeto para tags"
  type        = string
  default     = "lanchonete"
}

locals {
  common_tags = {
    Projeto   = var.nome_projeto
    ManagedBy = "terraform"
    Service   = "pagamento"
  }
}
