#!/bin/bash

# Script para aplicar o API Gateway com URLs dos Load Balancers
# Uso: ./scripts/apply-api-gateway.sh
#
# Este script lê automaticamente as URLs dos Load Balancers do Kubernetes
# e aplica o Terraform do API Gateway.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"

echo "🔗 Obtendo URLs dos Load Balancers..."
echo ""

# Obter URLs dos Load Balancers
CLIENTES_LB=$(kubectl get svc clientes-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
PAGAMENTO_LB=$(kubectl get svc pagamento-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
PEDIDOS_LB=$(kubectl get svc pedidos-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
COZINHA_LB=$(kubectl get svc cozinha-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

# Verificar se todos os LBs estão disponíveis
MISSING=""
[ -z "$CLIENTES_LB" ] && MISSING="$MISSING clientes"
[ -z "$PAGAMENTO_LB" ] && MISSING="$MISSING pagamento"
[ -z "$PEDIDOS_LB" ] && MISSING="$MISSING pedidos"
[ -z "$COZINHA_LB" ] && MISSING="$MISSING cozinha"

if [ -n "$MISSING" ]; then
    echo "❌ Load Balancers não disponíveis para:$MISSING"
    echo ""
    echo "   Verifique se os serviços estão deployados:"
    echo "   kubectl get svc"
    echo ""
    echo "   Se os serviços existem mas não têm EXTERNAL-IP, aguarde alguns minutos."
    exit 1
fi

echo "  Clientes:  http://$CLIENTES_LB"
echo "  Pagamento: http://$PAGAMENTO_LB"
echo "  Pedidos:   http://$PEDIDOS_LB"
echo "  Cozinha:   http://$COZINHA_LB"
echo ""

echo "📦 Aplicando Terraform do API Gateway..."
echo ""

cd "$INFRA_DIR/terraform/api-gateway"

terraform init -upgrade

terraform apply -auto-approve \
    -var="clientes_service_url=http://$CLIENTES_LB" \
    -var="pagamento_service_url=http://$PAGAMENTO_LB" \
    -var="pedidos_service_url=http://$PEDIDOS_LB" \
    -var="cozinha_service_url=http://$COZINHA_LB"

echo ""
echo "✅ API Gateway aplicado com sucesso!"
echo ""

# Mostrar URL do API Gateway
API_URL=$(terraform output -raw api_gateway_url 2>/dev/null || echo "")
if [ -n "$API_URL" ]; then
    echo "🌐 URL do API Gateway: $API_URL"
fi

echo ""
echo "Próximo passo: ./scripts/05-update-lambda-url.sh"
