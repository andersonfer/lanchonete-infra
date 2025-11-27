#!/bin/bash

# Script para atualizar a Lambda com a URL do serviço de clientes
# Uso: ./scripts/update-lambda-url.sh
#
# Este script lê a URL do Load Balancer do serviço de clientes
# e atualiza a variável de ambiente da Lambda.

set -e

echo "🔄 Atualizando Lambda com URL do serviço de clientes..."
echo ""

# Obter URL do Load Balancer do clientes
CLIENTES_URL=$(kubectl get svc clientes-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

if [ -z "$CLIENTES_URL" ]; then
    echo "❌ URL do serviço de clientes não disponível."
    echo "   Verifique se o serviço está deployado e o Load Balancer está ativo:"
    echo "   kubectl get svc clientes-service"
    exit 1
fi

echo "📡 URL do clientes: http://$CLIENTES_URL"
echo ""

# Obter configuração atual da Lambda
echo "📥 Obtendo configuração atual da Lambda..."
CURRENT_CONFIG=$(aws lambda get-function-configuration --function-name lanchonete-auth-lambda --query 'Environment.Variables' --output json 2>/dev/null)

if [ -z "$CURRENT_CONFIG" ] || [ "$CURRENT_CONFIG" == "null" ]; then
    echo "❌ Não foi possível obter a configuração da Lambda."
    echo "   Verifique se a Lambda foi criada corretamente."
    exit 1
fi

CLIENT_ID=$(echo $CURRENT_CONFIG | jq -r '.CLIENT_ID // empty')
USER_POOL_ID=$(echo $CURRENT_CONFIG | jq -r '.USER_POOL_ID // empty')

if [ -z "$CLIENT_ID" ] || [ -z "$USER_POOL_ID" ]; then
    echo "❌ Variáveis CLIENT_ID ou USER_POOL_ID não encontradas na Lambda."
    exit 1
fi

echo "  CLIENT_ID: $CLIENT_ID"
echo "  USER_POOL_ID: $USER_POOL_ID"
echo ""

# Atualizar Lambda
echo "📤 Atualizando Lambda..."
aws lambda update-function-configuration \
    --function-name lanchonete-auth-lambda \
    --environment "Variables={CLIENT_ID=$CLIENT_ID,USER_POOL_ID=$USER_POOL_ID,CLIENTES_SERVICE_URL=http://$CLIENTES_URL}" \
    --query 'Environment.Variables' \
    --output table

echo ""
echo "✅ Lambda atualizada com sucesso!"
echo ""
echo "✅ Deploy completo! Para testar:"
echo "   ./test_scripts/test-e2e-anonimo.sh"
echo "   ./test_scripts/test-e2e-identificado.sh"
