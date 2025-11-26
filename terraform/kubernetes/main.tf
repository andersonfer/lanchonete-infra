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

# Configurações locais para evitar repetição
locals {
  prefix = var.nome_projeto

  common_tags = {
    Projeto   = var.nome_projeto
    ManagedBy = "terraform"
  }
}

# Busca o LabRole existente no ambiente AWS
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# Busca a VPC padrão
data "aws_vpc" "padrao" {
  default = true
}

# Busca subnets em zonas suportadas pelo EKS
data "aws_subnets" "disponiveis" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.padrao.id]
  }

  filter {
    name   = "availability-zone"
    values = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d", "us-east-1f"]
  }
}

# Security Group para o cluster EKS
resource "aws_security_group" "eks_cluster" {
  name_prefix = "${local.prefix}-eks-"
  description = "Security group para cluster EKS"
  vpc_id      = data.aws_vpc.padrao.id

  # Permite todo tráfego de saída
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.prefix}-eks-sg"
    }
  )
}

# Cluster EKS usando LabRole
resource "aws_eks_cluster" "principal" {
  name     = "${local.prefix}-cluster"
  role_arn = data.aws_iam_role.lab_role.arn
  version  = "1.28"

  vpc_config {
    subnet_ids              = data.aws_subnets.disponiveis.ids
    security_group_ids      = [aws_security_group.eks_cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.prefix}-cluster"
    }
  )
}

# Node Group usando LabRole
resource "aws_eks_node_group" "aplicacao" {
  cluster_name    = aws_eks_cluster.principal.name
  node_group_name = "${local.prefix}-nodes"
  node_role_arn   = data.aws_iam_role.lab_role.arn
  subnet_ids      = data.aws_subnets.disponiveis.ids

  # Configuração mínima
  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.medium"]
  disk_size      = 20

  tags = merge(
    local.common_tags,
    {
      Name = "${local.prefix}-nodes"
    }
  )
}

# Busca o Security Group criado automaticamente pelo EKS para os nodes
data "aws_security_group" "eks_node_group" {
  depends_on = [aws_eks_node_group.aplicacao]
  
  filter {
    name   = "group-name"
    values = ["eks-cluster-sg-${aws_eks_cluster.principal.name}-*"]
  }
  
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.padrao.id]
  }
}

# Regra para NodePort do Autoatendimento (porta 30080)
resource "aws_security_group_rule" "nodeport_autoatendimento" {
  depends_on = [data.aws_security_group.eks_node_group]
  
  type              = "ingress"
  from_port         = 30080
  to_port           = 30080
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = data.aws_security_group.eks_node_group.id
  
  description = "Acesso externo para NodePort do autoatendimento"
}

# Regra para NodePort do Pagamento (porta 30081)
resource "aws_security_group_rule" "nodeport_pagamento" {
  depends_on = [data.aws_security_group.eks_node_group]

  type              = "ingress"
  from_port         = 30081
  to_port           = 30081
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = data.aws_security_group.eks_node_group.id

  description = "Acesso externo para NodePort do pagamento"
}

# Regra para permitir tráfego HTTP de Load Balancers
resource "aws_security_group_rule" "lb_http" {
  depends_on = [data.aws_security_group.eks_node_group]

  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = data.aws_security_group.eks_node_group.id

  description = "Acesso HTTP para Services LoadBalancer"
}

# ===== OUTPUTS PARA PIPELINE CI/CD =====

output "cluster_endpoint" {
  description = "Endpoint do cluster EKS"
  value       = aws_eks_cluster.principal.endpoint
}

output "cluster_name" {
  description = "Nome do cluster EKS"
  value       = aws_eks_cluster.principal.name
}

output "cluster_security_group_id" {
  description = "ID do security group do cluster"
  value       = aws_security_group.eks_cluster.id
}

output "cluster_certificate_authority_data" {
  description = "Certificado CA do cluster (sensível)"
  value       = aws_eks_cluster.principal.certificate_authority[0].data
  sensitive   = true
}

output "vpc_id" {
  description = "ID da VPC utilizada"
  value       = data.aws_vpc.padrao.id
}

output "regiao" {
  description = "Região AWS utilizada"
  value       = var.regiao_aws
}

output "node_group_security_group_id" {
  description = "ID do security group dos nodes EKS"
  value       = data.aws_security_group.eks_node_group.id
}