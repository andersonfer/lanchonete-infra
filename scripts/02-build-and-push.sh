#!/bin/bash

# Script para build e push das imagens Docker para ECR
# Uso: ./scripts/build-and-push.sh
#
# Requer que os repositórios dos microserviços estejam em:
#   ../lanchonete-clientes
#   ../lanchonete-pagamento
#   ../lanchonete-pedidos
#   ../lanchonete-cozinha

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"
REPOS_DIR="$(dirname "$INFRA_DIR")"

SERVICES=("clientes" "pagamento" "pedidos" "cozinha")

echo "🔍 Coletando informações do ECR..."

# Obter Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ -z "$ACCOUNT_ID" ]; then
    echo "❌ Erro: Não foi possível obter Account ID. Verifique as credenciais AWS."
    exit 1
fi

ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com"
echo "  ECR Registry: $ECR_REGISTRY"

echo ""
echo "🔐 Fazendo login no ECR..."
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REGISTRY

echo ""
echo "🏗️  Fazendo build e push das imagens..."
echo ""

for SERVICE in "${SERVICES[@]}"; do
    REPO_DIR="$REPOS_DIR/lanchonete-$SERVICE"
    IMAGE_NAME="lanchonete-$SERVICE"

    if [ ! -d "$REPO_DIR" ]; then
        echo "⚠️  Repositório não encontrado: $REPO_DIR"
        echo "   Pulando $SERVICE..."
        continue
    fi

    echo "📦 [$SERVICE] Building..."
    cd "$REPO_DIR"
    docker build -t $IMAGE_NAME:latest .

    echo "🏷️  [$SERVICE] Tagging..."
    docker tag $IMAGE_NAME:latest $ECR_REGISTRY/$IMAGE_NAME:latest

    echo "⬆️  [$SERVICE] Pushing..."
    docker push $ECR_REGISTRY/$IMAGE_NAME:latest

    echo "✅ [$SERVICE] Concluído!"
    echo ""
done

echo "🔍 Verificando imagens no ECR..."
echo ""

for SERVICE in "${SERVICES[@]}"; do
    IMAGE_NAME="lanchonete-$SERVICE"
    echo "  $IMAGE_NAME:"
    aws ecr describe-images --repository-name $IMAGE_NAME \
        --query 'sort_by(imageDetails,& imagePushedAt)[-1].[imageTags[0],imagePushedAt]' \
        --output text 2>/dev/null || echo "    (não encontrado)"
done

echo ""
echo "✅ Build e push completos!"
echo ""
echo "Próximo passo: ./scripts/03-deploy-k8s.sh"
