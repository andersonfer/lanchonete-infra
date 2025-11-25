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
    key            = "lambda/terraform.tfstate"
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

# Buscar outputs do módulo auth (Cognito)
data "terraform_remote_state" "auth" {
  backend = "s3"
  config = {
    bucket = "lanchonete-terraform-state-poc"
    key    = "auth/terraform.tfstate"
    region = "us-east-1"
  }
}

# Lambda Function usando ZIP já pronto
resource "aws_lambda_function" "auth_lambda" {
  filename         = "${path.module}/lambda-auth.zip"
  function_name    = "${var.nome_projeto}-auth-lambda"
  role            = data.aws_iam_role.lab_role.arn
  handler         = "br.com.lanchonete.auth.AuthHandler::handleRequest"
  runtime         = "java17"
  timeout         = 30
  memory_size     = 512

  # Variáveis de ambiente vindas do remote state e variáveis
  environment {
    variables = {
      USER_POOL_ID         = data.terraform_remote_state.auth.outputs.user_pool_id
      CLIENT_ID            = data.terraform_remote_state.auth.outputs.user_pool_client_id
      CLIENTES_SERVICE_URL = var.clientes_service_url
    }
  }

  source_code_hash = filebase64sha256("${path.module}/lambda-auth.zip")

  tags = local.common_tags
}

# Obter account ID atual
data "aws_caller_identity" "current" {}

# Permissão para API Gateway invocar a Lambda
resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auth_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # Permitir qualquer API Gateway nesta conta
  source_arn = "arn:aws:execute-api:${var.regiao}:${data.aws_caller_identity.current.account_id}:*/*/*"
}