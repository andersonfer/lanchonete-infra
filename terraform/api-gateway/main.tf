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
    key            = "api-gateway/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "lanchonete-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.regiao
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

# Buscar outputs do módulo lambda
data "terraform_remote_state" "lambda" {
  backend = "s3"
  config = {
    bucket = "lanchonete-terraform-state-poc"
    key    = "lambda/terraform.tfstate"
    region = "us-east-1"
  }
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "lanchonete_api" {
  name        = "${var.nome_projeto}-api"
  description = "API Gateway para lanchonete com autenticação Cognito - 4 microserviços"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = local.common_tags
}

# Authorizer do Cognito
resource "aws_api_gateway_authorizer" "cognito_authorizer" {
  name                   = "${var.nome_projeto}-cognito-authorizer"
  rest_api_id            = aws_api_gateway_rest_api.lanchonete_api.id
  type                   = "COGNITO_USER_POOLS"
  provider_arns          = [data.terraform_remote_state.auth.outputs.user_pool_arn]
  identity_source        = "method.request.header.Authorization"
  authorizer_credentials = ""
}

# ================================
# RECURSOS DE AUTENTICAÇÃO
# ================================

# Resource /auth
resource "aws_api_gateway_resource" "auth_resource" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  parent_id   = aws_api_gateway_rest_api.lanchonete_api.root_resource_id
  path_part   = "auth"
}

# Resource /auth/identificar
resource "aws_api_gateway_resource" "identificar_resource" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  parent_id   = aws_api_gateway_resource.auth_resource.id
  path_part   = "identificar"
}

# Method POST /auth/identificar (sem autorização)
resource "aws_api_gateway_method" "identificar_post" {
  rest_api_id   = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id   = aws_api_gateway_resource.identificar_resource.id
  http_method   = "POST"
  authorization = "NONE"

  request_models = {
    "application/json" = "Empty"
  }
}

# Integration com Lambda
resource "aws_api_gateway_integration" "identificar_lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id = aws_api_gateway_resource.identificar_resource.id
  http_method = aws_api_gateway_method.identificar_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = data.terraform_remote_state.lambda.outputs.lambda_invoke_arn
}

# ================================
# MICROSERVIÇO: CLIENTES
# ================================

# Resource /clientes
resource "aws_api_gateway_resource" "clientes_resource" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  parent_id   = aws_api_gateway_rest_api.lanchonete_api.root_resource_id
  path_part   = "clientes"
}

# Method GET /clientes (raiz - com autorização Cognito)
resource "aws_api_gateway_method" "clientes_root_get" {
  rest_api_id   = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id   = aws_api_gateway_resource.clientes_resource.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
}

# Integration GET /clientes (raiz) com LoadBalancer Clientes
resource "aws_api_gateway_integration" "clientes_root_get_integration" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id = aws_api_gateway_resource.clientes_resource.id
  http_method = aws_api_gateway_method.clientes_root_get.http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "GET"
  uri                     = "${var.clientes_service_url}/clientes"
}

# Method POST /clientes (raiz - com autorização Cognito)
resource "aws_api_gateway_method" "clientes_root_post" {
  rest_api_id   = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id   = aws_api_gateway_resource.clientes_resource.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
}

# Integration POST /clientes (raiz) com LoadBalancer Clientes
resource "aws_api_gateway_integration" "clientes_root_post_integration" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id = aws_api_gateway_resource.clientes_resource.id
  http_method = aws_api_gateway_method.clientes_root_post.http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "POST"
  uri                     = "${var.clientes_service_url}/clientes"
}

# Resource /clientes/{proxy+}
resource "aws_api_gateway_resource" "clientes_proxy" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  parent_id   = aws_api_gateway_resource.clientes_resource.id
  path_part   = "{proxy+}"
}

# Method GET /clientes/{proxy+} (com autorização Cognito)
resource "aws_api_gateway_method" "clientes_proxy_get" {
  rest_api_id   = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id   = aws_api_gateway_resource.clientes_proxy.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

# Integration GET /clientes/{proxy+} com LoadBalancer Clientes
resource "aws_api_gateway_integration" "clientes_proxy_get_integration" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id = aws_api_gateway_resource.clientes_proxy.id
  http_method = aws_api_gateway_method.clientes_proxy_get.http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "GET"
  uri                     = "${var.clientes_service_url}/clientes/{proxy}"

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

# ================================
# MICROSERVIÇO: PEDIDOS
# ================================

# Resource /pedidos
resource "aws_api_gateway_resource" "pedidos_resource" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  parent_id   = aws_api_gateway_rest_api.lanchonete_api.root_resource_id
  path_part   = "pedidos"
}

# Method GET /pedidos (raiz - com autorização Cognito)
resource "aws_api_gateway_method" "pedidos_root_get" {
  rest_api_id   = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id   = aws_api_gateway_resource.pedidos_resource.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
}

# Integration GET /pedidos (raiz) com LoadBalancer Pedidos
resource "aws_api_gateway_integration" "pedidos_root_get_integration" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id = aws_api_gateway_resource.pedidos_resource.id
  http_method = aws_api_gateway_method.pedidos_root_get.http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "GET"
  uri                     = "${var.pedidos_service_url}/pedidos"
}

# Method POST /pedidos (raiz - com autorização Cognito)
resource "aws_api_gateway_method" "pedidos_root_post" {
  rest_api_id   = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id   = aws_api_gateway_resource.pedidos_resource.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
}

# Integration POST /pedidos (raiz) com LoadBalancer Pedidos
resource "aws_api_gateway_integration" "pedidos_root_post_integration" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id = aws_api_gateway_resource.pedidos_resource.id
  http_method = aws_api_gateway_method.pedidos_root_post.http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "POST"
  uri                     = "${var.pedidos_service_url}/pedidos"
}

# Resource /pedidos/{proxy+}
resource "aws_api_gateway_resource" "pedidos_proxy" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  parent_id   = aws_api_gateway_resource.pedidos_resource.id
  path_part   = "{proxy+}"
}

# Method GET /pedidos/{proxy+} (com autorização Cognito)
resource "aws_api_gateway_method" "pedidos_proxy_get" {
  rest_api_id   = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id   = aws_api_gateway_resource.pedidos_proxy.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

# Integration GET /pedidos/{proxy+} com LoadBalancer Pedidos
resource "aws_api_gateway_integration" "pedidos_proxy_get_integration" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id = aws_api_gateway_resource.pedidos_proxy.id
  http_method = aws_api_gateway_method.pedidos_proxy_get.http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "GET"
  uri                     = "${var.pedidos_service_url}/pedidos/{proxy}"

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

# Method PUT /pedidos/{proxy+} (com autorização Cognito)
resource "aws_api_gateway_method" "pedidos_proxy_put" {
  rest_api_id   = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id   = aws_api_gateway_resource.pedidos_proxy.id
  http_method   = "PUT"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

# Integration PUT /pedidos/{proxy+} com LoadBalancer Pedidos
resource "aws_api_gateway_integration" "pedidos_proxy_put_integration" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id = aws_api_gateway_resource.pedidos_proxy.id
  http_method = aws_api_gateway_method.pedidos_proxy_put.http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "PUT"
  uri                     = "${var.pedidos_service_url}/pedidos/{proxy}"

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

# ================================
# MICROSERVIÇO: COZINHA
# ================================

# Resource /cozinha
resource "aws_api_gateway_resource" "cozinha_resource" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  parent_id   = aws_api_gateway_rest_api.lanchonete_api.root_resource_id
  path_part   = "cozinha"
}

# Method GET /cozinha (raiz - com autorização Cognito)
resource "aws_api_gateway_method" "cozinha_root_get" {
  rest_api_id   = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id   = aws_api_gateway_resource.cozinha_resource.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
}

# Integration GET /cozinha (raiz) com LoadBalancer Cozinha
resource "aws_api_gateway_integration" "cozinha_root_get_integration" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id = aws_api_gateway_resource.cozinha_resource.id
  http_method = aws_api_gateway_method.cozinha_root_get.http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "GET"
  uri                     = "${var.cozinha_service_url}/cozinha"
}

# Resource /cozinha/{proxy+}
resource "aws_api_gateway_resource" "cozinha_proxy" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  parent_id   = aws_api_gateway_resource.cozinha_resource.id
  path_part   = "{proxy+}"
}

# Method GET /cozinha/{proxy+} (com autorização Cognito)
resource "aws_api_gateway_method" "cozinha_proxy_get" {
  rest_api_id   = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id   = aws_api_gateway_resource.cozinha_proxy.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

# Integration GET /cozinha/{proxy+} com LoadBalancer Cozinha
resource "aws_api_gateway_integration" "cozinha_proxy_get_integration" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id = aws_api_gateway_resource.cozinha_proxy.id
  http_method = aws_api_gateway_method.cozinha_proxy_get.http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "GET"
  uri                     = "${var.cozinha_service_url}/cozinha/{proxy}"

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

# Method POST /cozinha/{proxy+} (com autorização Cognito)
resource "aws_api_gateway_method" "cozinha_proxy_post" {
  rest_api_id   = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id   = aws_api_gateway_resource.cozinha_proxy.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

# Integration POST /cozinha/{proxy+} com LoadBalancer Cozinha
resource "aws_api_gateway_integration" "cozinha_proxy_post_integration" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id = aws_api_gateway_resource.cozinha_proxy.id
  http_method = aws_api_gateway_method.cozinha_proxy_post.http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "POST"
  uri                     = "${var.cozinha_service_url}/cozinha/{proxy}"

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

# ================================
# MICROSERVIÇO: PAGAMENTO
# ================================

# Resource /pagamento
resource "aws_api_gateway_resource" "pagamento_resource" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  parent_id   = aws_api_gateway_rest_api.lanchonete_api.root_resource_id
  path_part   = "pagamento"
}

# Method GET /pagamento (raiz - com autorização Cognito)
resource "aws_api_gateway_method" "pagamento_root_get" {
  rest_api_id   = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id   = aws_api_gateway_resource.pagamento_resource.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
}

# Integration GET /pagamento (raiz) com LoadBalancer Pagamento
resource "aws_api_gateway_integration" "pagamento_root_get_integration" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id = aws_api_gateway_resource.pagamento_resource.id
  http_method = aws_api_gateway_method.pagamento_root_get.http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "GET"
  uri                     = "${var.pagamento_service_url}/pagamento"
}

# Method POST /pagamento (raiz - com autorização Cognito)
resource "aws_api_gateway_method" "pagamento_root_post" {
  rest_api_id   = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id   = aws_api_gateway_resource.pagamento_resource.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
}

# Integration POST /pagamento (raiz) com LoadBalancer Pagamento
resource "aws_api_gateway_integration" "pagamento_root_post_integration" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id = aws_api_gateway_resource.pagamento_resource.id
  http_method = aws_api_gateway_method.pagamento_root_post.http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "POST"
  uri                     = "${var.pagamento_service_url}/pagamento"
}

# Resource /pagamento/{proxy+}
resource "aws_api_gateway_resource" "pagamento_proxy" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  parent_id   = aws_api_gateway_resource.pagamento_resource.id
  path_part   = "{proxy+}"
}

# Method GET /pagamento/{proxy+} (com autorização Cognito)
resource "aws_api_gateway_method" "pagamento_proxy_get" {
  rest_api_id   = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id   = aws_api_gateway_resource.pagamento_proxy.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

# Integration GET /pagamento/{proxy+} com LoadBalancer Pagamento
resource "aws_api_gateway_integration" "pagamento_proxy_get_integration" {
  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id
  resource_id = aws_api_gateway_resource.pagamento_proxy.id
  http_method = aws_api_gateway_method.pagamento_proxy_get.http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "GET"
  uri                     = "${var.pagamento_service_url}/pagamento/{proxy}"

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

# ================================
# CORS E DEPLOYMENT
# ================================

# Deployment
resource "aws_api_gateway_deployment" "lanchonete_deployment" {
  depends_on = [
    aws_api_gateway_integration.identificar_lambda_integration,
    aws_api_gateway_integration.clientes_root_get_integration,
    aws_api_gateway_integration.clientes_root_post_integration,
    aws_api_gateway_integration.clientes_proxy_get_integration,
    aws_api_gateway_integration.pedidos_root_get_integration,
    aws_api_gateway_integration.pedidos_root_post_integration,
    aws_api_gateway_integration.pedidos_proxy_get_integration,
    aws_api_gateway_integration.pedidos_proxy_put_integration,
    aws_api_gateway_integration.cozinha_root_get_integration,
    aws_api_gateway_integration.cozinha_proxy_get_integration,
    aws_api_gateway_integration.cozinha_proxy_post_integration,
    aws_api_gateway_integration.pagamento_root_get_integration,
    aws_api_gateway_integration.pagamento_root_post_integration,
    aws_api_gateway_integration.pagamento_proxy_get_integration,
  ]

  rest_api_id = aws_api_gateway_rest_api.lanchonete_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.auth_resource.id,
      aws_api_gateway_resource.identificar_resource.id,
      aws_api_gateway_method.identificar_post.id,
      aws_api_gateway_integration.identificar_lambda_integration.id,
      aws_api_gateway_resource.clientes_resource.id,
      aws_api_gateway_resource.clientes_proxy.id,
      aws_api_gateway_method.clientes_root_get.id,
      aws_api_gateway_method.clientes_root_post.id,
      aws_api_gateway_method.clientes_proxy_get.id,
      aws_api_gateway_integration.clientes_root_get_integration.id,
      aws_api_gateway_integration.clientes_root_post_integration.id,
      aws_api_gateway_integration.clientes_proxy_get_integration.id,
      aws_api_gateway_resource.pedidos_resource.id,
      aws_api_gateway_resource.pedidos_proxy.id,
      aws_api_gateway_method.pedidos_root_get.id,
      aws_api_gateway_method.pedidos_root_post.id,
      aws_api_gateway_method.pedidos_proxy_get.id,
      aws_api_gateway_method.pedidos_proxy_put.id,
      aws_api_gateway_integration.pedidos_root_get_integration.id,
      aws_api_gateway_integration.pedidos_root_post_integration.id,
      aws_api_gateway_integration.pedidos_proxy_get_integration.id,
      aws_api_gateway_integration.pedidos_proxy_put_integration.id,
      aws_api_gateway_resource.cozinha_resource.id,
      aws_api_gateway_resource.cozinha_proxy.id,
      aws_api_gateway_method.cozinha_root_get.id,
      aws_api_gateway_method.cozinha_proxy_get.id,
      aws_api_gateway_method.cozinha_proxy_post.id,
      aws_api_gateway_integration.cozinha_root_get_integration.id,
      aws_api_gateway_integration.cozinha_proxy_get_integration.id,
      aws_api_gateway_integration.cozinha_proxy_post_integration.id,
      aws_api_gateway_resource.pagamento_resource.id,
      aws_api_gateway_resource.pagamento_proxy.id,
      aws_api_gateway_method.pagamento_root_get.id,
      aws_api_gateway_method.pagamento_root_post.id,
      aws_api_gateway_method.pagamento_proxy_get.id,
      aws_api_gateway_integration.pagamento_root_get_integration.id,
      aws_api_gateway_integration.pagamento_root_post_integration.id,
      aws_api_gateway_integration.pagamento_proxy_get_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Stage
resource "aws_api_gateway_stage" "lanchonete_stage" {
  deployment_id = aws_api_gateway_deployment.lanchonete_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.lanchonete_api.id
  stage_name    = "v1"

  tags = local.common_tags
}
