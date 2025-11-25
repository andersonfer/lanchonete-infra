terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "lanchonete-terraform-state-poc"
    key            = "auth/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "lanchonete-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.regiao
}

# Obter informações da role do Lab
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# Cognito User Pool para autenticação via CPF
resource "aws_cognito_user_pool" "lanchonete_auth" {
  name = "${var.nome_projeto}-auth"

  # CPF será usado como username (sem email)
  # username_attributes não é definido = usar username padrão
  
  # Permitir auto-cadastro
  auto_verified_attributes = []

  # Políticas de senha (relaxadas pois usaremos fluxo customizado com CPF)
  password_policy {
    minimum_length    = 8
    require_lowercase = false
    require_numbers   = false
    require_symbols   = false
    require_uppercase = false
  }

  # CPF será usado diretamente como username, sem schema adicional

  # Configurações de dispositivo
  device_configuration {
    challenge_required_on_new_device      = false
    device_only_remembered_on_user_prompt = false
  }

  # Desabilitar verificações de email/SMS
  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
  }

  tags = local.common_tags
}

# Cognito User Pool Client
resource "aws_cognito_user_pool_client" "lanchonete_auth_client" {
  name         = "${var.nome_projeto}-auth-client"
  user_pool_id = aws_cognito_user_pool.lanchonete_auth.id

  # Configurações de autenticação (usar apenas novos flows)
  explicit_auth_flows = [
    "ALLOW_ADMIN_USER_PASSWORD_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_CUSTOM_AUTH"
  ]

  # Tempo de vida dos tokens
  access_token_validity  = 60    # 1 hora para identificados
  id_token_validity      = 60    # 1 hora
  refresh_token_validity = 1440  # 1 dia

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "minutes"
  }

  # Não requer secret
  generate_secret = false

  # Configurações de OAuth
  supported_identity_providers = ["COGNITO"]
}

# User Pool Domain para hosted UI (se necessário)
resource "aws_cognito_user_pool_domain" "lanchonete_auth_domain" {
  domain       = "${var.nome_projeto}-auth-${random_string.domain_suffix.result}"
  user_pool_id = aws_cognito_user_pool.lanchonete_auth.id
}

# String aleatória para domínio único
resource "random_string" "domain_suffix" {
  length  = 8
  special = false
  upper   = false
}