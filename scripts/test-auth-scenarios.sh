#!/bin/bash

# Script para testar todos os cenários de autenticação
# Autor: Claude
# Data: 2025-09-17

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Diretório base do projeto (um nível acima de scripts/)
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Função para obter URLs dinamicamente
get_api_gateway_url() {
    echo "Obtendo URL do API Gateway..." >&2
    cd "$PROJECT_DIR/infra/api-gateway"
    url=$(terraform output -raw api_gateway_endpoint 2>/dev/null)
    if [ -z "$url" ]; then
        echo "Erro: Não foi possível obter a URL do API Gateway" >&2
        exit 1
    fi
    echo "$url"
}

get_alb_urls() {
    echo "Obtendo URLs dos ALBs..." >&2
    albs=$(kubectl get ingress -o json 2>/dev/null)
    if [ -z "$albs" ]; then
        echo "Erro: Não foi possível obter as URLs dos ALBs" >&2
        exit 1
    fi

    AUTOATENDIMENTO_ALB=$(echo "$albs" | jq -r '.items[] | select(.metadata.name=="autoatendimento-ingress") | .status.loadBalancer.ingress[0].hostname' | sed 's/^/http:\/\//')
    PAGAMENTO_ALB=$(echo "$albs" | jq -r '.items[] | select(.metadata.name=="pagamento-ingress") | .status.loadBalancer.ingress[0].hostname' | sed 's/^/http:\/\//')

    if [ -z "$AUTOATENDIMENTO_ALB" ] || [ "$AUTOATENDIMENTO_ALB" == "http://null" ]; then
        echo "Erro: Não foi possível obter a URL do ALB de Autoatendimento" >&2
        exit 1
    fi

    if [ -z "$PAGAMENTO_ALB" ] || [ "$PAGAMENTO_ALB" == "http://null" ]; then
        echo "Erro: Não foi possível obter a URL do ALB de Pagamento" >&2
        exit 1
    fi
}

# Função para imprimir com cores
print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Função para fazer requisições e verificar status
make_request() {
    local method=$1
    local url=$2
    local data=$3
    local token=$4
    local expected_status=$5

    if [ -z "$token" ]; then
        if [ -z "$data" ]; then
            response=$(curl -s -w "\n%{http_code}" -X "$method" "$url" -H "Content-Type: application/json")
        else
            response=$(curl -s -w "\n%{http_code}" -X "$method" "$url" -H "Content-Type: application/json" -d "$data")
        fi
    else
        if [ -z "$data" ]; then
            response=$(curl -s -w "\n%{http_code}" -X "$method" "$url" -H "Content-Type: application/json" -H "Authorization: Bearer $token")
        else
            response=$(curl -s -w "\n%{http_code}" -X "$method" "$url" -H "Content-Type: application/json" -H "Authorization: Bearer $token" -d "$data")
        fi
    fi

    status_code=$(echo "$response" | tail -n 1)
    body=$(echo "$response" | head -n -1)

    if [ "$status_code" == "$expected_status" ]; then
        echo "$body"
        return 0
    else
        print_error "Esperado status $expected_status, recebido $status_code"
        echo "$body"
        return 1
    fi
}

# Função para executar fluxo completo
test_complete_flow() {
    local cpf=$1
    local test_name=$2
    local token=$3

    print_info "Executando fluxo completo para: $test_name"

    local categoria=$4
    local produto_id=$5
    local produto_nome=$6

    # 1. Buscar produtos
    print_info "Buscando produtos da categoria $categoria..."
    products=$(make_request GET "$API_GATEWAY_URL/autoatendimento/produtos/categoria/$categoria" "" "$token" "200")
    if [ $? -eq 0 ]; then
        print_success "Produtos encontrados"
        echo "$products" | jq ".[0]" 2>/dev/null || echo "$products" | head -1
    else
        print_error "Falha ao buscar produtos"
        return 1
    fi

    # 2. Criar pedido
    print_info "Criando pedido com $produto_nome..."
    if [ -z "$cpf" ] || [ "$cpf" == "null" ]; then
        order_data="{\"cpfCliente\": null, \"itens\": [{\"produtoId\": $produto_id, \"quantidade\": 1}]}"
    else
        order_data="{\"cpfCliente\": \"$cpf\", \"itens\": [{\"produtoId\": $produto_id, \"quantidade\": 1}]}"
    fi

    order=$(make_request POST "$API_GATEWAY_URL/autoatendimento/pedidos/checkout" "$order_data" "$token" "201")
    if [ $? -eq 0 ]; then
        order_id=$(echo "$order" | jq -r '.id' 2>/dev/null || echo "$order" | grep -o '"id":[0-9]*' | cut -d: -f2)
        order_number=$(echo "$order" | jq -r '.numeroPedido' 2>/dev/null || echo "$order" | grep -o '"numeroPedido":"[^"]*"' | cut -d'"' -f4)
        order_total=$(echo "$order" | jq -r '.valorTotal' 2>/dev/null || echo "$order" | grep -o '"valorTotal":[0-9.]*' | cut -d: -f2)
        print_success "Pedido $order_number criado (ID: $order_id, Total: R$ $order_total)"
    else
        print_error "Falha ao criar pedido"
        return 1
    fi

    # 3. Processar pagamento
    print_info "Processando pagamento..."
    payment_data="{\"pedidoId\": \"$order_id\", \"valor\": $order_total}"
    payment=$(make_request POST "$PAGAMENTO_ALB/pagamentos" "$payment_data" "" "200")
    if [ $? -eq 0 ]; then
        print_success "Pagamento iniciado"
    else
        print_error "Falha ao iniciar pagamento"
        return 1
    fi

    # 4. Aguardar processamento
    print_info "Aguardando processamento do pagamento (3 segundos)..."
    sleep 3

    # 5. Verificar status final
    print_info "Verificando status do pagamento..."
    status=$(make_request GET "$API_GATEWAY_URL/autoatendimento/pedidos/$order_id/pagamento/status" "" "$token" "200")
    if [ $? -eq 0 ]; then
        payment_status=$(echo "$status" | jq -r '.statusPagamento' 2>/dev/null || echo "$status" | grep -o '"statusPagamento":"[^"]*"' | cut -d'"' -f4)
        if [ "$payment_status" == "APROVADO" ]; then
            print_success "Pagamento APROVADO ✓"
        else
            print_info "Pagamento $payment_status (comportamento aleatório do mock)"
        fi
        echo "$status" | jq '.' 2>/dev/null || echo "$status"
    else
        print_error "Falha ao verificar status"
        return 1
    fi

    return 0
}

# ═══════════════════════════════════════════════════════════
# INÍCIO DOS TESTES
# ═══════════════════════════════════════════════════════════

clear
echo -e "${GREEN}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         TESTE DE CENÁRIOS DE AUTENTICAÇÃO                 ║"
echo "║              Sistema de Lanchonete                        ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Obter URLs dinamicamente
print_info "Obtendo configurações da infraestrutura..."
API_GATEWAY_URL=$(get_api_gateway_url)
get_alb_urls

# Voltar ao diretório de scripts após obter as configurações
cd "$PROJECT_DIR/scripts"

print_success "Configurações obtidas:"
echo "  API Gateway: $API_GATEWAY_URL"
echo "  ALB Autoatendimento: $AUTOATENDIMENTO_ALB"
echo "  ALB Pagamento: $PAGAMENTO_ALB"

# Verificar conectividade
print_info "Verificando conectividade com os serviços..."
curl -s -o /dev/null -w "API Gateway: %{http_code}\n" "$API_GATEWAY_URL/auth/identificar" || true
curl -s -o /dev/null -w "ALB Autoatendimento: %{http_code}\n" "$AUTOATENDIMENTO_ALB/actuator/health" || true
curl -s -o /dev/null -w "ALB Pagamento: %{http_code}\n" "$PAGAMENTO_ALB/actuator/health" || true

# ═══════════════════════════════════════════════════════════
# TESTE 1: SEGURANÇA - CLIENTE NÃO AUTENTICADO
# ═══════════════════════════════════════════════════════════

print_header "TESTE 1: SEGURANÇA - CLIENTE NÃO AUTENTICADO"

print_info "Testando proteção dos endpoints sem autenticação..."

# Testar busca de produtos sem token
print_info "Tentando buscar produtos sem token JWT..."
unauth_products=$(make_request GET "$API_GATEWAY_URL/autoatendimento/produtos/categoria/LANCHE" "" "" "401" 2>/dev/null)
if [ $? -eq 0 ]; then
    print_success "Endpoint protegido corretamente - acesso negado sem autenticação"
    echo "$unauth_products"
else
    print_error "FALHA DE SEGURANÇA: Endpoint acessível sem autenticação!"
fi

# Testar criação de pedido sem token
print_info "Tentando criar pedido sem token JWT..."
order_data='{"cpfCliente": "12345678900", "itens": [{"produtoId": 1, "quantidade": 1}]}'
unauth_order=$(make_request POST "$API_GATEWAY_URL/autoatendimento/pedidos/checkout" "$order_data" "" "401" 2>/dev/null)
if [ $? -eq 0 ]; then
    print_success "Endpoint de checkout protegido corretamente"
    echo "$unauth_order"
else
    print_error "FALHA DE SEGURANÇA: Criação de pedido possível sem autenticação!"
fi

# Testar com token inválido
print_info "Tentando acessar com token JWT inválido..."
fake_token="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
invalid_token_response=$(make_request GET "$API_GATEWAY_URL/autoatendimento/produtos/categoria/LANCHE" "" "$fake_token" "401" 2>/dev/null)
if [ $? -eq 0 ]; then
    print_success "Token inválido rejeitado corretamente"
    echo "$invalid_token_response"
else
    print_error "FALHA DE SEGURANÇA: Token inválido aceito!"
fi

print_success "Testes de segurança concluídos - Sistema protegido adequadamente"

# ═══════════════════════════════════════════════════════════
# TESTE 2: CLIENTE ANÔNIMO
# ═══════════════════════════════════════════════════════════

print_header "TESTE 2: CLIENTE ANÔNIMO (sem CPF)"

print_info "Autenticando cliente anônimo..."
auth_response=$(make_request POST "$API_GATEWAY_URL/auth/identificar" '{"cpf": null}' "" "200")
if [ $? -eq 0 ]; then
    token=$(echo "$auth_response" | jq -r '.accessToken' 2>/dev/null || echo "$auth_response" | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4)
    tipo=$(echo "$auth_response" | jq -r '.tipo' 2>/dev/null || echo "$auth_response" | grep -o '"tipo":"[^"]*"' | cut -d'"' -f4)
    print_success "Cliente anônimo autenticado (Tipo: $tipo)"

    # Executar fluxo completo
    test_complete_flow "null" "Cliente Anônimo" "$token" "LANCHE" "1" "X-Burger"
else
    print_error "Falha na autenticação anônima"
fi

# ═══════════════════════════════════════════════════════════
# TESTE 3: CLIENTE NOVO
# ═══════════════════════════════════════════════════════════

print_header "TESTE 3: CLIENTE NOVO (CPF inexistente)"

# Gerar CPF aleatório
random_cpf=$(printf "%011d" $((RANDOM * RANDOM)))
print_info "Testando com CPF novo: $random_cpf"

print_info "Autenticando cliente novo..."
auth_response=$(make_request POST "$API_GATEWAY_URL/auth/identificar" "{\"cpf\": \"$random_cpf\"}" "" "200")
if [ $? -eq 0 ]; then
    token=$(echo "$auth_response" | jq -r '.accessToken' 2>/dev/null || echo "$auth_response" | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4)
    tipo=$(echo "$auth_response" | jq -r '.tipo' 2>/dev/null || echo "$auth_response" | grep -o '"tipo":"[^"]*"' | cut -d'"' -f4)
    print_success "Cliente novo autenticado e criado automaticamente (Tipo: $tipo)"

    # Verificar se foi criado no banco
    print_info "Verificando se cliente foi criado no banco..."
    client=$(curl -s "$AUTOATENDIMENTO_ALB/clientes/cpf/$random_cpf")
    if echo "$client" | grep -q "$random_cpf"; then
        print_success "Cliente confirmado no banco de dados"
        echo "$client" | jq '.' 2>/dev/null || echo "$client"
    fi

    # Executar fluxo completo
    test_complete_flow "$random_cpf" "Cliente Novo" "$token" "BEBIDA" "5" "Refrigerante Lata"
else
    print_error "Falha na autenticação de cliente novo"
fi

# ═══════════════════════════════════════════════════════════
# TESTE 4: CLIENTE CRIADO VIA ENDPOINT
# ═══════════════════════════════════════════════════════════

print_header "TESTE 4: CLIENTE CRIADO VIA ENDPOINT"

# Gerar CPF aleatório
endpoint_cpf=$(printf "%011d" $((RANDOM * RANDOM + 1000)))
print_info "Criando cliente via endpoint com CPF: $endpoint_cpf"

# Criar cliente via API
client_data="{\"nome\": \"Cliente Teste API\", \"cpf\": \"$endpoint_cpf\", \"email\": \"teste$endpoint_cpf@lanchonete.com\"}"
create_response=$(make_request POST "$AUTOATENDIMENTO_ALB/clientes" "$client_data" "" "201")
if [ $? -eq 0 ]; then
    client_id=$(echo "$create_response" | jq -r '.id' 2>/dev/null || echo "$create_response" | grep -o '"id":[0-9]*' | cut -d: -f2)
    print_success "Cliente criado no banco (ID: $client_id)"
    echo "$create_response" | jq '.' 2>/dev/null || echo "$create_response"

    # Agora autenticar
    print_info "Autenticando cliente criado via endpoint..."
    auth_response=$(make_request POST "$API_GATEWAY_URL/auth/identificar" "{\"cpf\": \"$endpoint_cpf\"}" "" "200")
    if [ $? -eq 0 ]; then
        token=$(echo "$auth_response" | jq -r '.accessToken' 2>/dev/null || echo "$auth_response" | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4)
        tipo=$(echo "$auth_response" | jq -r '.tipo' 2>/dev/null || echo "$auth_response" | grep -o '"tipo":"[^"]*"' | cut -d'"' -f4)
        print_success "Cliente autenticado (Tipo: $tipo)"

        # Executar fluxo completo
        test_complete_flow "$endpoint_cpf" "Cliente Criado via Endpoint" "$token" "ACOMPANHAMENTO" "2" "Batata Frita P"
    else
        print_error "Falha na autenticação"
    fi
else
    print_error "Falha ao criar cliente via endpoint"
fi

# ═══════════════════════════════════════════════════════════
# TESTE 5: CLIENTE PRÉ-EXISTENTE
# ═══════════════════════════════════════════════════════════

print_header "TESTE 5: CLIENTE PRÉ-EXISTENTE NO BANCO (João da Silva - 55555555555)"

print_info "Verificando se cliente existe no banco..."
client=$(curl -s "$AUTOATENDIMENTO_ALB/clientes/cpf/55555555555")
if echo "$client" | grep -q "55555555555"; then
    print_success "Cliente João da Silva encontrado no banco"
    echo "$client" | jq '.' 2>/dev/null || echo "$client"

    print_info "Autenticando cliente pré-existente..."
    auth_response=$(make_request POST "$API_GATEWAY_URL/auth/identificar" '{"cpf": "55555555555"}' "" "200")
    if [ $? -eq 0 ]; then
        token=$(echo "$auth_response" | jq -r '.accessToken' 2>/dev/null || echo "$auth_response" | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4)
        tipo=$(echo "$auth_response" | jq -r '.tipo' 2>/dev/null || echo "$auth_response" | grep -o '"tipo":"[^"]*"' | cut -d'"' -f4)
        print_success "Cliente pré-existente autenticado (Tipo: $tipo)"

        # Executar fluxo completo
        test_complete_flow "55555555555" "Cliente Pré-existente (João da Silva)" "$token" "SOBREMESA" "10" "Brownie"
    else
        print_error "Falha na autenticação"
    fi
else
    print_error "Cliente João da Silva não encontrado no banco"
    print_info "Criando cliente João da Silva..."
    client_data='{"nome": "João da Silva", "cpf": "55555555555", "email": "joao.silva@lanchonete.com"}'
    create_response=$(make_request POST "$AUTOATENDIMENTO_ALB/clientes" "$client_data" "" "201")
    if [ $? -eq 0 ]; then
        print_success "Cliente criado com sucesso"
        # Repetir o teste
        print_info "Tentando autenticar novamente..."
        auth_response=$(make_request POST "$API_GATEWAY_URL/auth/identificar" '{"cpf": "55555555555"}' "" "200")
        if [ $? -eq 0 ]; then
            token=$(echo "$auth_response" | jq -r '.accessToken' 2>/dev/null || echo "$auth_response" | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4)
            print_success "Cliente autenticado após criação"
            test_complete_flow "55555555555" "Cliente João da Silva" "$token" "SOBREMESA" "10" "Brownie"
        fi
    fi
fi

# ═══════════════════════════════════════════════════════════
# RESUMO FINAL
# ═══════════════════════════════════════════════════════════

print_header "RESUMO DOS TESTES"

echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Todos os cenários de autenticação foram testados!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Cenários testados:"
echo "  1. Segurança - Cliente Não Autenticado"
echo "  2. Cliente Anônimo (sem CPF)"
echo "  3. Cliente Novo (CPF gerado aleatoriamente)"
echo "  4. Cliente Criado via Endpoint"
echo "  5. Cliente Pré-existente (João da Silva)"
echo ""
echo -e "${BLUE}Script finalizado com sucesso!${NC}"