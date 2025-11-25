#!/bin/bash

# Script para atualizar manifests Kubernetes com valores dinâmicos do Terraform
# Uso: ./scripts/update-manifests.sh

set -e

echo "🔍 Coletando informações da infraestrutura..."

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

# Obter endpoint RDS
RDS_ENDPOINT=$(cd infra/database && terraform output -raw rds_endpoint 2>/dev/null) || RDS_ENDPOINT=""

echo "📝 Valores coletados:"
echo "  ECR Registry: $ECR_REGISTRY"
echo "  RDS Endpoint: $RDS_ENDPOINT"

# Validar se conseguiu obter o ECR Registry
if [ -z "$ECR_REGISTRY" ]; then
    echo "❌ Erro: Não foi possível obter ECR Registry nem via Terraform nem via AWS CLI"
    exit 1
fi

echo "🔄 Atualizando manifests..."

# Substituir qualquer registry ECR existente pelo registry correto
# Padrão: [ACCOUNT_ID].dkr.ecr.us-east-1.amazonaws.com
find k8s_manifests -name "*.yaml" -o -name "*.yml" | while read file; do
    # Verifica se o arquivo contém algum registry ECR
    if grep -q "[0-9]\{12\}\.dkr\.ecr\.us-east-1\.amazonaws\.com" "$file"; then
        echo "  Atualizando registry ECR em $file"
        # Substitui qualquer ID de conta AWS (12 dígitos) pelo registry correto
        sed -i "s|[0-9]\{12\}\.dkr\.ecr\.us-east-1\.amazonaws\.com|${ECR_REGISTRY}|g" "$file"
    fi
done

# Substituir RDS_ENDPOINT nos manifests (se houver placeholder)
find k8s_manifests -name "*.yaml" -o -name "*.yml" | while read file; do
    if grep -q "RDS_ENDPOINT" "$file"; then
        echo "  Atualizando RDS endpoint em $file"
        sed -i "s|RDS_ENDPOINT|${RDS_ENDPOINT}|g" "$file"
    fi
done

echo "✅ Manifests atualizados com sucesso!"
echo ""
echo "📋 Próximos passos:"
echo "  1. Fazer build e push das imagens Docker"
echo "  2. Criar Secrets do RDS"
echo "  3. Aplicar manifests no cluster"