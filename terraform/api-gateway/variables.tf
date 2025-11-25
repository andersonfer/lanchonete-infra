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

variable "clientes_service_url" {
  description = "URL do LoadBalancer do serviço de clientes (ex: http://xxx.elb.amazonaws.com:8080)"
  type        = string
}

variable "pedidos_service_url" {
  description = "URL do LoadBalancer do serviço de pedidos (ex: http://xxx.elb.amazonaws.com:8080)"
  type        = string
}

variable "cozinha_service_url" {
  description = "URL do LoadBalancer do serviço de cozinha (ex: http://xxx.elb.amazonaws.com:8080)"
  type        = string
}

variable "pagamento_service_url" {
  description = "URL do LoadBalancer do serviço de pagamento (ex: http://xxx.elb.amazonaws.com:8080)"
  type        = string
}

locals {
  common_tags = {
    Projeto = var.nome_projeto
    Terraform = "true"
  }
}