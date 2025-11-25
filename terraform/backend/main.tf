# Configuração do Terraform para criar o backend remoto
# Este módulo deve ser executado PRIMEIRO, antes dos outros módulos
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

# Variáveis
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

# Configurações locais
locals {
  prefix = var.nome_projeto

  common_tags = {
    Projeto   = var.nome_projeto
    ManagedBy = "terraform"
    Purpose   = "terraform-backend"
  }
}

# Bucket S3 para armazenar o estado do Terraform
resource "aws_s3_bucket" "terraform_state" {
  bucket = "lanchonete-terraform-state-poc"

  # Previne deleção acidental
  lifecycle {
    prevent_destroy = false # POC permite destruir
  }

  tags = local.common_tags
}

# Criptografia do bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bloqueia acesso público ao bucket
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Tabela DynamoDB para lock do estado
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "${local.prefix}-terraform-locks"
  billing_mode = "PAY_PER_REQUEST" # POC usa pay-per-request
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = local.common_tags
}

# ===== OUTPUTS =====

output "s3_bucket_name" {
  description = "Nome do bucket S3 para estado do Terraform"
  value       = aws_s3_bucket.terraform_state.id
}

output "dynamodb_table_name" {
  description = "Nome da tabela DynamoDB para locks"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "regiao" {
  description = "Região onde o backend foi criado"
  value       = var.regiao_aws
}