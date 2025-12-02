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

    if ! command -v curl &> /dev/null; then
        echo "❌ curl não encontrado"
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

# Função para validar credenciais do MongoDB Atlas ANTES do Terraform
# Evita o erro HTTP 401 que ocorre quando a API Key não está associada ao Project
validate_atlas_credentials() {
    echo "🔐 Validando credenciais MongoDB Atlas..."

    # Verificar se as variáveis de ambiente existem
    if [ -z "$MONGODB_ATLAS_PUBLIC_KEY" ] || [ -z "$MONGODB_ATLAS_PRIVATE_KEY" ]; then
        echo "❌ Variáveis de ambiente do MongoDB Atlas não definidas"
        echo "   Defina: MONGODB_ATLAS_PUBLIC_KEY e MONGODB_ATLAS_PRIVATE_KEY"
        return 1
    fi

    # Ler Project ID do terraform.tfvars
    local TFVARS_FILE="$TERRAFORM_DIR/mongodb-atlas/terraform.tfvars"
    if [ ! -f "$TFVARS_FILE" ]; then
        echo "❌ Arquivo terraform.tfvars não encontrado: $TFVARS_FILE"
        echo "   Crie o arquivo com: atlas_project_id = \"SEU_PROJECT_ID\""
        return 1
    fi

    local PROJECT_ID=$(grep atlas_project_id "$TFVARS_FILE" | cut -d'"' -f2)
    if [ -z "$PROJECT_ID" ]; then
        echo "❌ atlas_project_id não encontrado em terraform.tfvars"
        return 1
    fi

    # Testar autenticação com a API do MongoDB Atlas
    # Usa Digest Authentication + header Accept obrigatório para API v2
    local HTTP_CODE=$(curl -s -o /tmp/atlas_response.json -w "%{http_code}" \
        --user "${MONGODB_ATLAS_PUBLIC_KEY}:${MONGODB_ATLAS_PRIVATE_KEY}" \
        --digest \
        -H "Accept: application/vnd.atlas.2023-01-01+json" \
        "https://cloud.mongodb.com/api/atlas/v2/groups/${PROJECT_ID}")

    if [ "$HTTP_CODE" != "200" ]; then
        echo "❌ Credenciais MongoDB Atlas inválidas (HTTP $HTTP_CODE)"
        echo ""
        echo "   CAUSA PROVÁVEL: API Key não está associada ao Project"
        echo ""
        echo "   SOLUÇÃO:"
        echo "   1. Acesse https://cloud.mongodb.com"
        echo "   2. Vá em Project Settings → Access Manager"
        echo "   3. Clique 'Invite to Project'"
        echo "   4. Selecione a API Key existente (ou crie uma nova)"
        echo "   5. Dê permissão 'Project Owner'"
        echo "   6. Re-execute este script"
        echo ""

        # Mostrar detalhes do erro se disponível
        if [ -f /tmp/atlas_response.json ]; then
            local ERROR_MSG=$(jq -r '.detail // .error // "Sem detalhes"' /tmp/atlas_response.json 2>/dev/null)
            echo "   Detalhes: $ERROR_MSG"
        fi

        return 1
    fi

    echo "✅ Credenciais MongoDB Atlas válidas!"
    echo "   Project ID: $PROJECT_ID"
    return 0
}

# Função para aplicar MongoDB Atlas de forma idempotente
# Verifica se o cluster já existe e importa no Terraform se necessário
apply_mongodb_atlas() {
    echo "📦 Aplicando módulo: mongodb-atlas"

    local TFVARS_FILE="$TERRAFORM_DIR/mongodb-atlas/terraform.tfvars"
    local PROJECT_ID=$(grep atlas_project_id "$TFVARS_FILE" | cut -d'"' -f2)
    local CLUSTER_NAME="pagamento-cluster"

    cd "$TERRAFORM_DIR/mongodb-atlas"
    terraform init -upgrade

    # Verificar se o cluster já existe na API do Atlas
    echo "🔍 Verificando se cluster '$CLUSTER_NAME' já existe..."
    local CLUSTER_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" \
        --user "${MONGODB_ATLAS_PUBLIC_KEY}:${MONGODB_ATLAS_PRIVATE_KEY}" \
        --digest \
        -H "Accept: application/vnd.atlas.2023-01-01+json" \
        "https://cloud.mongodb.com/api/atlas/v2/groups/${PROJECT_ID}/clusters/${CLUSTER_NAME}")

    if [ "$CLUSTER_EXISTS" = "200" ]; then
        echo "   Cluster encontrado no Atlas!"

        # Verificar se já está no Terraform state
        if terraform state show mongodbatlas_advanced_cluster.pagamento &>/dev/null; then
            echo "   ✅ Cluster já está no Terraform state"
        else
            echo "   ⚡ Importando cluster existente no Terraform..."
            terraform import mongodbatlas_advanced_cluster.pagamento "${PROJECT_ID}-${CLUSTER_NAME}"
        fi
    else
        echo "   Cluster não existe, será criado pelo Terraform"
    fi

    # Verificar se o database user já existe
    local DB_USER="pagamento_user"
    echo "🔍 Verificando se usuário '$DB_USER' já existe..."
    local USER_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" \
        --user "${MONGODB_ATLAS_PUBLIC_KEY}:${MONGODB_ATLAS_PRIVATE_KEY}" \
        --digest \
        -H "Accept: application/vnd.atlas.2023-01-01+json" \
        "https://cloud.mongodb.com/api/atlas/v2/groups/${PROJECT_ID}/databaseUsers/admin/${DB_USER}")

    if [ "$USER_EXISTS" = "200" ]; then
        echo "   Usuário encontrado no Atlas!"
        if terraform state show mongodbatlas_database_user.pagamento &>/dev/null; then
            echo "   ✅ Usuário já está no Terraform state"
        else
            echo "   ⚡ Importando usuário existente no Terraform..."
            terraform import mongodbatlas_database_user.pagamento "${PROJECT_ID}-${DB_USER}-admin"
        fi
    fi

    # Verificar IP Access List (0.0.0.0/0)
    echo "🔍 Verificando IP Access List..."
    if terraform state show mongodbatlas_project_ip_access_list.allow_all &>/dev/null; then
        echo "   ✅ IP Access List já está no Terraform state"
    else
        local IP_EXISTS=$(curl -s \
            --user "${MONGODB_ATLAS_PUBLIC_KEY}:${MONGODB_ATLAS_PRIVATE_KEY}" \
            --digest \
            -H "Accept: application/vnd.atlas.2023-01-01+json" \
            "https://cloud.mongodb.com/api/atlas/v2/groups/${PROJECT_ID}/accessList" | jq -r '.results[] | select(.cidrBlock == "0.0.0.0/0") | .cidrBlock')

        if [ "$IP_EXISTS" = "0.0.0.0/0" ]; then
            echo "   ⚡ Importando IP Access List existente..."
            terraform import mongodbatlas_project_ip_access_list.allow_all "${PROJECT_ID}-0.0.0.0/0"
        fi
    fi

    echo ""
    echo "🚀 Executando terraform apply..."
    terraform apply -auto-approve

    echo "✅ Módulo mongodb-atlas aplicado com sucesso!"
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

    # Criar secrets (inclui MySQL, RabbitMQ e MongoDB Atlas)
    echo "  → Criando secrets..."
    "$SCRIPT_DIR/create-secrets.sh"

    # Aplicar RabbitMQ
    echo "  → Aplicando RabbitMQ..."
    kubectl apply -f "$INFRA_DIR/k8s/shared-rabbitmq-statefulset.yaml"

    # NOTA: MongoDB agora usa Atlas (provisionado via Terraform)
    # O secret mongodb-atlas-secret já foi criado pelo create-secrets.sh

    # Aguardar pods ficarem prontos
    echo "  → Aguardando RabbitMQ ficar pronto..."
    kubectl wait --for=condition=ready pod -l app=shared-rabbitmq --timeout=120s || true

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

# 4. RDS (Database MySQL)
apply_terraform "database"

# 5. MongoDB Atlas (idempotente - importa recursos existentes automaticamente)
if validate_atlas_credentials; then
    apply_mongodb_atlas
else
    echo "⚠️  Pulando módulo mongodb-atlas devido a erro de autenticação"
    echo "   Corrija o problema e re-execute o script"
    exit 1
fi

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

# 6. Lambda (URL do clientes será atualizada depois via 05-update-lambda-url.sh)
apply_terraform "lambda"

echo "✅ Infraestrutura base provisionada com sucesso!"
echo ""
echo "Próximo passo: ./scripts/02-build-and-push.sh"
