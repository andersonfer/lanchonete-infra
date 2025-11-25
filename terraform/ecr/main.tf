# Configuração do Terraform
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Provider AWS - usa LabRole automaticamente via AWS CLI/credentials
provider "aws" {
  region = var.regiao_aws
}

# Variáveis essenciais
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

variable "servicos" {
  description = "Lista dos serviços que precisam de repositórios ECR"
  type        = list(string)
  default     = ["clientes", "pedidos", "cozinha", "pagamento"]

  validation {
    condition     = length(var.servicos) > 0
    error_message = "A lista de serviços não pode estar vazia."
  }
}

# Configurações locais consolidadas
locals {
  prefix   = var.nome_projeto
  servicos = var.servicos

  common_tags = {
    Projeto   = var.nome_projeto
    ManagedBy = "terraform"
    Purpose   = "container-registry"
  }
}

# Repositórios ECR para cada serviço
resource "aws_ecr_repository" "repos" {
  count = length(local.servicos)

  name                 = "${local.prefix}-${local.servicos[count.index]}"
  image_tag_mutability = "MUTABLE" # Permite sobrescrever tags (bom para POC)

  # Configuração de scanning de imagens
  image_scanning_configuration {
    scan_on_push = false # Desabilitado para POC (economiza custo e tempo)
  }

  tags = merge(
    local.common_tags,
    {
      Name    = "${local.prefix}-${local.servicos[count.index]}"
      Servico = local.servicos[count.index]
    }
  )
}

# Política de ciclo de vida para limpar imagens antigas (economiza custo)
resource "aws_ecr_lifecycle_policy" "cleanup" {
  count      = length(local.servicos)
  repository = aws_ecr_repository.repos[count.index].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Manter apenas as 10 imagens mais recentes"
        selection = {
          tagStatus   = "untagged"
          countType   = "imageCountMoreThan"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Manter apenas as 10 tags mais recentes"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "latest", "main", "feature"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ===== OUTPUTS =====

output "repositorios_ecr" {
  description = "URLs dos repositórios ECR criados"
  value = {
    for idx, servico in local.servicos : servico => aws_ecr_repository.repos[idx].repository_url
  }
}

output "registry_url" {
  description = "URL base do registry ECR"
  value       = split("/", aws_ecr_repository.repos[0].repository_url)[0]
}

output "repositorios_nomes" {
  description = "Nomes dos repositórios ECR"
  value = {
    for idx, servico in local.servicos : servico => aws_ecr_repository.repos[idx].name
  }
}