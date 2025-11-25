variable "nome_projeto" {
  description = "Nome do projeto"
  type        = string
  default     = "lanchonete"
}

variable "regiao" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

locals {
  common_tags = {
    Projeto = var.nome_projeto
    Terraform = "true"
  }
}