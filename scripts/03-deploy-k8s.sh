#!/bin/bash

# Script para aplicar manifests Kubernetes dos microserviços
# Uso: ./scripts/03-deploy-k8s.sh
#
# Este script substitui automaticamente os placeholders {{ECR_*}} nos
# arquivos deployment.yaml pelo endereço ECR correto antes de aplicar.
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

echo "🚀 Iniciando deploy no Kubernetes..."
echo ""

echo "🔍 Verificando conexão com cluster..."
kubectl cluster-info --context $(kubectl config current-context) | head -1
echo ""

# Obter Account ID para construir URL do ECR
echo "🔍 Obtendo informações do ECR..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ -z "$ACCOUNT_ID" ]; then
    echo "❌ Erro: Não foi possível obter Account ID. Verifique as credenciais AWS."
    exit 1
fi
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com"
echo "  ECR Registry: $ECR_REGISTRY"
echo ""

for SERVICE in "${SERVICES[@]}"; do
    REPO_DIR="$REPOS_DIR/lanchonete-$SERVICE"
    K8S_DIR="$REPO_DIR/k8s"
    SERVICE_UPPER=$(echo "$SERVICE" | tr '[:lower:]' '[:upper:]')
    ECR_IMAGE="${ECR_REGISTRY}/lanchonete-${SERVICE}:latest"

    if [ ! -d "$K8S_DIR" ]; then
        echo "⚠️  Diretório k8s não encontrado: $K8S_DIR"
        echo "   Pulando $SERVICE..."
        continue
    fi

    echo "📦 [$SERVICE] Aplicando manifests..."

    # Aplicar todos os arquivos exceto deployment.yaml primeiro
    for file in "$K8S_DIR"/*.yaml; do
        if [ -f "$file" ] && [ "$(basename "$file")" != "deployment.yaml" ]; then
            kubectl apply -f "$file"
        fi
    done

    # Aplicar deployment.yaml com substituição do placeholder ECR
    DEPLOYMENT_FILE="$K8S_DIR/deployment.yaml"
    if [ -f "$DEPLOYMENT_FILE" ]; then
        echo "  Substituindo {{ECR_${SERVICE_UPPER}}} por $ECR_IMAGE"
        sed "s|{{ECR_${SERVICE_UPPER}}}|${ECR_IMAGE}|g" "$DEPLOYMENT_FILE" | kubectl apply -f -
    fi

    echo "✅ [$SERVICE] Aplicado!"
    echo ""
done

echo "⏳ Aguardando deployments ficarem prontos..."
for SERVICE in "${SERVICES[@]}"; do
    echo "  Aguardando $SERVICE..."
    kubectl wait --for=condition=available --timeout=300s deployment/${SERVICE}-deployment 2>/dev/null || \
        echo "  ⚠️  Timeout aguardando $SERVICE (pode estar iniciando)"
done

echo ""
echo "✅ Deploy completo!"
echo ""

echo "📋 Status dos recursos:"
echo ""
echo "🏗️  DEPLOYMENTS:"
kubectl get deployments -o wide
echo ""
echo "🌐 SERVICES:"
kubectl get services -o wide
echo ""
echo "📦 PODS:"
kubectl get pods -o wide

echo ""
echo "⏳ Aguarde os Load Balancers ficarem ativos (1-2 minutos)..."
echo "   Use: kubectl get svc -w"
echo ""
echo "📋 Próximo passo: ./scripts/04-apply-api-gateway.sh"
