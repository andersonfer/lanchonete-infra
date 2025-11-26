#!/bin/bash

# Script para aplicar manifests Kubernetes dos microserviços
# Uso: ./scripts/deploy-k8s.sh
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

for SERVICE in "${SERVICES[@]}"; do
    REPO_DIR="$REPOS_DIR/lanchonete-$SERVICE"
    K8S_DIR="$REPO_DIR/k8s"

    if [ ! -d "$K8S_DIR" ]; then
        echo "⚠️  Diretório k8s não encontrado: $K8S_DIR"
        echo "   Pulando $SERVICE..."
        continue
    fi

    echo "📦 [$SERVICE] Aplicando manifests..."
    kubectl apply -f "$K8S_DIR/"
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
echo "📋 Próximo passo: ./scripts/apply-api-gateway.sh"
