#!/bin/bash

# Script para build e push das imagens Docker para ECR
# Uso: ./scripts/build-and-push.sh

set -e

echo "🔍 Coletando informações do ECR..."

# Obter registry ECR com fallback
ECR_REGISTRY=$(cd infra/ecr && terraform output -raw registry_url 2>/dev/null | grep -E '^[0-9]{12}\.dkr\.ecr\.' | head -1) || ECR_REGISTRY=""

# Se Terraform falhar, usar AWS CLI como fallback
if [ -z "$ECR_REGISTRY" ]; then
    echo "⚠️  Terraform output vazio, usando AWS CLI como fallback..."
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
    if [ -n "$ACCOUNT_ID" ]; then
        ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com"
        echo "    Calculado ECR Registry: $ECR_REGISTRY"
    fi
fi

echo "  ECR Registry: $ECR_REGISTRY"

# Validar se conseguiu obter o ECR Registry
if [ -z "$ECR_REGISTRY" ]; then
    echo "❌ Erro: Não foi possível obter ECR Registry nem via Terraform nem via AWS CLI"
    exit 1
fi

echo "🔐 Fazendo login no ECR..."
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REGISTRY

echo "🏗️  Fazendo build das imagens..."

# Build autoatendimento
echo "  📦 Building autoatendimento..."
cd app/autoatendimento
docker build -t lanchonete-autoatendimento:latest .
docker tag lanchonete-autoatendimento:latest $ECR_REGISTRY/lanchonete-autoatendimento:latest
cd ../..

# Build pagamento
echo "  📦 Building pagamento..."
cd app/pagamento
docker build -t lanchonete-pagamento:latest .
docker tag lanchonete-pagamento:latest $ECR_REGISTRY/lanchonete-pagamento:latest
cd ../..

echo "🚀 Fazendo push das imagens para ECR..."

# Push autoatendimento
echo "  ⬆️  Pushing autoatendimento..."
docker push $ECR_REGISTRY/lanchonete-autoatendimento:latest

# Push pagamento
echo "  ⬆️  Pushing pagamento..."
docker push $ECR_REGISTRY/lanchonete-pagamento:latest

echo "✅ Build e push completos!"

echo "🔍 Verificando imagens no ECR..."
aws ecr describe-images --repository-name lanchonete-autoatendimento --query 'sort_by(imageDetails,& imagePushedAt)[-1].[imageTags[0],imagePushedAt]' --output table
aws ecr describe-images --repository-name lanchonete-pagamento --query 'sort_by(imageDetails,& imagePushedAt)[-1].[imageTags[0],imagePushedAt]' --output table

echo "📋 Imagens prontas para deploy no Kubernetes!"