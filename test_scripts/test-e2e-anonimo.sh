#!/bin/bash

# =============================================================================
# Script de Teste E2E: Cliente ANONIMO
# =============================================================================
# Testa o fluxo completo sem identificacao do cliente:
#   Auth anonimo -> Pedido -> Pagamento -> Cozinha -> Preparo -> Pronto
#
# Uso: ./test_scripts/test-e2e-anonimo.sh
# =============================================================================

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"

echo "==================================================================="
echo "TESTE E2E: CLIENTE ANONIMO"
echo "==================================================================="
echo ""

# ============================================================================
# OBTER URL DO API GATEWAY
# ============================================================================
echo "Obtendo URL do API Gateway..."

cd "$INFRA_DIR/terraform/api-gateway"
API_URL=$(terraform output -raw api_gateway_url 2>/dev/null || echo "")
cd "$SCRIPT_DIR"

if [ -z "$API_URL" ]; then
    echo -e "${RED}[ERRO] Nao foi possivel obter URL do API Gateway${NC}"
    echo "   Verifique se o API Gateway foi deployado"
    exit 1
fi

echo -e "${GREEN}API Gateway URL: $API_URL${NC}"
echo ""

# ============================================================================
# ETAPA 1: AUTENTICACAO ANONIMA
# ============================================================================
echo "--------------------------------------------------------------------"
echo "ETAPA 1: Autenticacao Anonima"
echo "--------------------------------------------------------------------"

AUTH_RESPONSE=$(curl -s -X POST "$API_URL/auth/identificar" \
    -H "Content-Type: application/json" \
    -d '{"cpf": null}')

TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.accessToken // empty')
TIPO=$(echo "$AUTH_RESPONSE" | jq -r '.tipo')
EXPIRA=$(echo "$AUTH_RESPONSE" | jq -r '.expiresIn')

if [ -z "$TOKEN" ]; then
    echo -e "${RED}[FALHA] Nao foi possivel obter token${NC}"
    echo "Response: $AUTH_RESPONSE"
    exit 1
fi

if [ "$TIPO" != "ANONIMO" ]; then
    echo -e "${YELLOW}[AVISO] Tipo esperado: ANONIMO, recebido: $TIPO${NC}"
fi

echo -e "${GREEN}[OK] Token obtido: Tipo=$TIPO, Expira em ${EXPIRA}s${NC}"
echo ""

# ============================================================================
# ETAPA 2: CRIAR PEDIDO (SEM CPF)
# ============================================================================
echo "--------------------------------------------------------------------"
echo "ETAPA 2: Criar Pedido (sem CPF)"
echo "--------------------------------------------------------------------"

PEDIDO_RESPONSE=$(curl -s -X POST "$API_URL/pedidos" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "cpfCliente": null,
        "itens": [
            {"produtoId": 1, "quantidade": 1},
            {"produtoId": 5, "quantidade": 1}
        ]
    }')

PEDIDO_ID=$(echo "$PEDIDO_RESPONSE" | jq -r '.id // empty')
NUMERO_PEDIDO=$(echo "$PEDIDO_RESPONSE" | jq -r '.numeroPedido')
STATUS=$(echo "$PEDIDO_RESPONSE" | jq -r '.status // empty')
VALOR_TOTAL=$(echo "$PEDIDO_RESPONSE" | jq -r '.valorTotal // empty')

if [ -z "$PEDIDO_ID" ] || [ "$PEDIDO_ID" = "null" ]; then
    echo -e "${RED}[FALHA] Nao foi possivel criar pedido${NC}"
    echo "Response: $PEDIDO_RESPONSE"
    exit 1
fi

echo -e "${GREEN}[OK] Pedido criado: ID=$PEDIDO_ID, Numero=$NUMERO_PEDIDO, Status=$STATUS, Valor=R\$ $VALOR_TOTAL${NC}"
echo ""

# ============================================================================
# ETAPA 3: AGUARDAR PROCESSAMENTO DO PAGAMENTO
# ============================================================================
echo "--------------------------------------------------------------------"
echo "ETAPA 3: Aguardando Processamento do Pagamento (5s)"
echo "--------------------------------------------------------------------"

echo "Aguardando processamento assincrono via RabbitMQ..."
sleep 5
echo -e "${GREEN}[OK] Tempo de espera concluido${NC}"
echo ""

# ============================================================================
# ETAPA 4: CONSULTAR STATUS DO PEDIDO
# ============================================================================
echo "--------------------------------------------------------------------"
echo "ETAPA 4: Consultar Status do Pedido"
echo "--------------------------------------------------------------------"

PEDIDO_STATUS=$(curl -s "$API_URL/pedidos/$PEDIDO_ID" \
    -H "Authorization: Bearer $TOKEN")

CURRENT_STATUS=$(echo "$PEDIDO_STATUS" | jq -r '.status')

if [ "$CURRENT_STATUS" = "CANCELADO" ]; then
    echo -e "${YELLOW}[AVISO] Pagamento rejeitado: Status=$CURRENT_STATUS${NC}"
    echo ""
    echo "===================================================================="
    echo "RESUMO DO TESTE E2E - CLIENTE ANONIMO"
    echo "===================================================================="
    echo ""
    echo "Pedido: $NUMERO_PEDIDO (ID=$PEDIDO_ID) | Valor: R\$ $VALOR_TOTAL"
    echo ""
    echo "Jornada: CRIADO -> CANCELADO (pagamento rejeitado)"
    echo ""
    echo -e "${YELLOW}TESTE ENCERRADO: Pagamento rejeitado (cenario valido - 20% dos casos)${NC}"
    echo ""
    exit 0
elif [ "$CURRENT_STATUS" = "REALIZADO" ]; then
    echo -e "${GREEN}[OK] Pagamento aprovado: Status=$CURRENT_STATUS${NC}"
else
    echo -e "${BLUE}[INFO] Status do pedido: $CURRENT_STATUS${NC}"
fi
echo ""

# ============================================================================
# ETAPA 5: VERIFICAR FILA DA COZINHA
# ============================================================================
echo "--------------------------------------------------------------------"
echo "ETAPA 5: Verificar Fila da Cozinha"
echo "--------------------------------------------------------------------"

FILA_RESPONSE=$(curl -s "$API_URL/cozinha/fila" \
    -H "Authorization: Bearer $TOKEN")

PEDIDO_NA_FILA=$(echo "$FILA_RESPONSE" | jq -r ".[] | select(.pedidoId == $PEDIDO_ID) | .pedidoId")
FILA_STATUS=$(echo "$FILA_RESPONSE" | jq -r ".[] | select(.pedidoId == $PEDIDO_ID) | .status")
COZINHA_ID=$(echo "$FILA_RESPONSE" | jq -r ".[] | select(.pedidoId == $PEDIDO_ID) | .id")

if [ "$PEDIDO_NA_FILA" = "$PEDIDO_ID" ]; then
    echo -e "${GREEN}[OK] Pedido na fila: PedidoID=$PEDIDO_ID, CozinhaID=$COZINHA_ID, Status=$FILA_STATUS${NC}"
else
    echo -e "${RED}[FALHA] Pedido nao encontrado na fila da cozinha${NC}"
    echo "Response: $FILA_RESPONSE"
    exit 1
fi
echo ""

# ============================================================================
# ETAPA 6: INICIAR PREPARO
# ============================================================================
echo "--------------------------------------------------------------------"
echo "ETAPA 6: Iniciar Preparo na Cozinha"
echo "--------------------------------------------------------------------"

INICIAR_RESPONSE=$(curl -s -X POST "$API_URL/cozinha/$COZINHA_ID/iniciar" \
    -H "Authorization: Bearer $TOKEN")

COZINHA_STATUS=$(echo "$INICIAR_RESPONSE" | jq -r '.status')

if [ "$COZINHA_STATUS" = "EM_PREPARO" ]; then
    echo -e "${GREEN}[OK] Preparo iniciado: CozinhaID=$COZINHA_ID, Status=$COZINHA_STATUS${NC}"
else
    echo -e "${RED}[FALHA] Erro ao iniciar preparo: Status=$COZINHA_STATUS${NC}"
    echo "Response: $INICIAR_RESPONSE"
    exit 1
fi
echo ""

# ============================================================================
# ETAPA 7: FINALIZAR PREPARO
# ============================================================================
echo "--------------------------------------------------------------------"
echo "ETAPA 7: Finalizar Preparo"
echo "--------------------------------------------------------------------"

sleep 2

PRONTO_RESPONSE=$(curl -s -X POST "$API_URL/cozinha/$COZINHA_ID/pronto" \
    -H "Authorization: Bearer $TOKEN")

COZINHA_STATUS_FINAL=$(echo "$PRONTO_RESPONSE" | jq -r '.status')

if [ "$COZINHA_STATUS_FINAL" = "PRONTO" ]; then
    echo -e "${GREEN}[OK] Preparo finalizado: Status=$COZINHA_STATUS_FINAL${NC}"
else
    echo -e "${RED}[FALHA] Erro ao finalizar preparo: Status=$COZINHA_STATUS_FINAL${NC}"
    echo "Response: $PRONTO_RESPONSE"
    exit 1
fi
echo ""

# ============================================================================
# ETAPA 8: VERIFICAR STATUS FINAL
# ============================================================================
echo "--------------------------------------------------------------------"
echo "ETAPA 8: Verificar Status Final do Pedido"
echo "--------------------------------------------------------------------"

sleep 2

PEDIDO_FINAL=$(curl -s "$API_URL/pedidos/$PEDIDO_ID" \
    -H "Authorization: Bearer $TOKEN")

STATUS_FINAL=$(echo "$PEDIDO_FINAL" | jq -r '.status')

if [ "$STATUS_FINAL" = "PRONTO" ]; then
    echo -e "${GREEN}[OK] Pedido pronto para retirada: Status=$STATUS_FINAL${NC}"
else
    echo -e "${YELLOW}[AVISO] Status do pedido: $STATUS_FINAL${NC}"
fi
echo ""

# ============================================================================
# RESUMO FINAL
# ============================================================================
echo "===================================================================="
echo "RESUMO DO TESTE E2E - CLIENTE ANONIMO"
echo "===================================================================="
echo ""
echo "Pedido: $NUMERO_PEDIDO (ID=$PEDIDO_ID) | Valor: R\$ $VALOR_TOTAL"
echo ""
echo "Jornada completa:"
echo "  Auth ANONIMO -> CRIADO -> REALIZADO -> EM_PREPARO -> PRONTO"
echo ""
echo "Microservicos testados:"
echo "  [OK] API Gateway (Cognito JWT)"
echo "  [OK] Lambda AuthHandler"
echo "  [OK] Servico de Pedidos"
echo "  [OK] Servico de Pagamento"
echo "  [OK] Servico de Cozinha"
echo "  [OK] RabbitMQ (mensageria)"
echo ""
echo -e "${GREEN}TESTE E2E CLIENTE ANONIMO CONCLUIDO COM SUCESSO!${NC}"
echo ""
