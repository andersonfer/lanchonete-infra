#!/bin/bash

# Script para deploy completo da infraestrutura AWS
# Uso: ./scripts/deploy-infra.sh
#
# Este script executa todos os módulos Terraform na ordem correta
# e aplica os recursos compartilhados do Kubernetes.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$INFRA_DIR/terraform"

echo "🚀 Iniciando deploy da infraestrutura Lanchonete..."
echo ""

# Verificar pré-requisitos
check_prerequisites() {
    echo "🔍 Verificando pré-requisitos..."

    if ! command -v terraform &> /dev/null; then
        echo "❌ Terraform não encontrado"
        exit 1
    fi

    if ! command -v aws &> /dev/null; then
        echo "❌ AWS CLI não encontrado"
        exit 1
    fi

    if ! command -v kubectl &> /dev/null; then
        echo "❌ kubectl não encontrado"
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        echo "❌ jq não encontrado"
        exit 1
    fi

    # Verificar credenciais AWS
    if ! aws sts get-caller-identity &> /dev/null; then
        echo "❌ Credenciais AWS inválidas ou expiradas"
        exit 1
    fi

    echo "✅ Todos os pré-requisitos atendidos!"
    echo ""
}

# Função para aplicar um módulo Terraform
apply_terraform() {
    local module=$1
    local extra_args=${2:-""}

    echo "📦 Aplicando módulo: $module"
    cd "$TERRAFORM_DIR/$module"

    terraform init -upgrade
    terraform apply -auto-approve $extra_args

    echo "✅ Módulo $module aplicado com sucesso!"
    echo ""
}

# Função para configurar kubectl
configure_kubectl() {
    echo "🔧 Configurando kubectl para EKS..."
    aws eks update-kubeconfig --name lanchonete-cluster --region us-east-1
    echo "✅ kubectl configurado!"
    echo ""
}

# Função para aplicar recursos k8s
apply_k8s_resources() {
    echo "☸️  Aplicando recursos Kubernetes..."

    # Criar secrets
    echo "  → Criando secrets..."
    "$SCRIPT_DIR/create-secrets.sh"

    # Aplicar RabbitMQ
    echo "  → Aplicando RabbitMQ..."
    kubectl apply -f "$INFRA_DIR/k8s/shared-rabbitmq-statefulset.yaml"

    # Aplicar MongoDB
    echo "  → Aplicando MongoDB..."
    kubectl apply -f "$INFRA_DIR/k8s/pagamento-mongodb-statefulset.yaml"

    # Aguardar pods ficarem prontos
    echo "  → Aguardando pods ficarem prontos..."
    kubectl wait --for=condition=ready pod -l app=shared-rabbitmq --timeout=120s || true
    kubectl wait --for=condition=ready pod -l app=pagamento-mongodb --timeout=120s || true

    echo "✅ Recursos Kubernetes aplicados!"
    echo ""
}

# MAIN
check_prerequisites

echo "=========================================="
echo "  FASE 1: Infraestrutura Base"
echo "=========================================="

# 1. Backend (S3 + DynamoDB)
apply_terraform "backend"

# 2. ECR (Container Registry)
apply_terraform "ecr"

# 3. EKS (Kubernetes)
apply_terraform "kubernetes"

# 4. RDS (Database)
apply_terraform "database"

echo "=========================================="
echo "  FASE 2: Configuração Kubernetes"
echo "=========================================="

# Configurar kubectl
configure_kubectl

# Aplicar recursos k8s (secrets, rabbitmq, mongodb)
apply_k8s_resources

echo "=========================================="
echo "  FASE 3: Autenticação"
echo "=========================================="

# 5. Cognito (Auth)
apply_terraform "auth"

# 6. Lambda (com URL vazia por enquanto)
apply_terraform "lambda" '-var="clientes_service_url="'

echo "=========================================="
echo "  INFORMAÇÕES IMPORTANTES"
echo "=========================================="

echo ""
echo "📋 Próximos passos manuais:"
echo ""
echo "1. Fazer build e push das imagens dos microserviços:"
echo "   ./scripts/build-and-push.sh"
echo ""
echo "2. Aplicar deployments dos microserviços (em cada repo):"
echo "   kubectl apply -f k8s/"
echo ""
echo "3. Aguardar Load Balancers ficarem disponíveis:"
echo "   kubectl get svc"
echo ""
echo "4. Aplicar API Gateway com URLs dos LBs:"
echo "   cd terraform/api-gateway && terraform apply \\"
echo "     -var=\"clientes_service_url=http://<clientes-lb>\" \\"
echo "     -var=\"pagamento_service_url=http://<pagamento-lb>\" \\"
echo "     -var=\"pedidos_service_url=http://<pedidos-lb>\" \\"
echo "     -var=\"cozinha_service_url=http://<cozinha-lb>\""
echo ""
echo "5. Atualizar Lambda com URL do clientes:"
echo "   ./scripts/update-lambda-url.sh"
echo ""

echo "✅ Infraestrutura base provisionada com sucesso!"
