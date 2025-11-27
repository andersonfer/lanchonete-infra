#!/bin/bash

# Script para criar Secret do MongoDB Atlas no Kubernetes
# Uso: ./scripts/create-atlas-secret.sh
#
# IMPORTANTE: Este script converte a connection string SRV para formato padrao
# porque o CoreDNS do EKS tem problemas com resolucao de registros SRV/TXT
# do MongoDB Atlas.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform/mongodb-atlas"

echo "🔐 Criando Secret do MongoDB Atlas..."
echo ""

# Verificar pre-requisitos
if ! command -v host &> /dev/null; then
    echo "❌ Comando 'host' nao encontrado. Instale com: sudo apt install bind9-host"
    exit 1
fi

# Verificar se o Terraform foi aplicado
if [ ! -d "$TERRAFORM_DIR/.terraform" ]; then
    echo "❌ Erro: Execute 'terraform init' e 'terraform apply' no modulo mongodb-atlas primeiro"
    echo "   cd $TERRAFORM_DIR && terraform init && terraform apply"
    exit 1
fi

# Obter dados do Terraform
cd "$TERRAFORM_DIR"

CLUSTER_HOST=$(terraform output -raw cluster_host 2>/dev/null || echo "")
DB_USER=$(terraform output -raw database_username 2>/dev/null || echo "")
DB_PASS=$(terraform output -raw database_password 2>/dev/null || echo "")
DB_NAME=$(terraform output -raw database_name 2>/dev/null || echo "")

if [ -z "$CLUSTER_HOST" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASS" ]; then
    echo "❌ Erro: Nao foi possivel obter dados do Terraform"
    echo "   Verifique se o cluster foi criado com 'terraform apply'"
    exit 1
fi

echo "✅ Dados obtidos do Terraform"
echo "   Cluster: $CLUSTER_HOST"
echo "   Database: $DB_NAME"
echo "   User: $DB_USER"

# Resolver SRV records para obter os hosts do replica set
echo ""
echo "🔍 Resolvendo DNS SRV records..."

SRV_HOSTS=$(host -t SRV "_mongodb._tcp.$CLUSTER_HOST" 2>/dev/null | grep "has SRV record" | awk '{print $NF}' | sed 's/\.$//' | sort)

if [ -z "$SRV_HOSTS" ]; then
    echo "❌ Erro: Nao foi possivel resolver SRV records para $CLUSTER_HOST"
    exit 1
fi

# Construir lista de hosts com porta
HOSTS_WITH_PORT=""
for host in $SRV_HOSTS; do
    if [ -n "$HOSTS_WITH_PORT" ]; then
        HOSTS_WITH_PORT="$HOSTS_WITH_PORT,"
    fi
    HOSTS_WITH_PORT="${HOSTS_WITH_PORT}${host}:27017"
done

echo "   Hosts: $HOSTS_WITH_PORT"

# Resolver TXT record para obter replica set name e authSource
echo ""
echo "🔍 Resolvendo DNS TXT record..."

TXT_RECORD=$(host -t TXT "$CLUSTER_HOST" 2>/dev/null | grep "descriptive text" | sed 's/.*descriptive text "\(.*\)"/\1/')

if [ -z "$TXT_RECORD" ]; then
    echo "⚠️  TXT record nao encontrado, usando valores padrao"
    TXT_RECORD="authSource=admin"
fi

echo "   TXT: $TXT_RECORD"

# Construir connection string padrao (nao-SRV)
# Formato: mongodb://user:pass@host1:27017,host2:27017,host3:27017/database?ssl=true&replicaSet=xxx&authSource=admin
MONGO_URI="mongodb://${DB_USER}:${DB_PASS}@${HOSTS_WITH_PORT}/${DB_NAME}?ssl=true&${TXT_RECORD}&retryWrites=true&w=majority"

echo ""
echo "✅ Connection string padrao construida"

# Criar secret no Kubernetes usando YAML para evitar problemas com caracteres especiais
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: mongodb-atlas-secret
type: Opaque
stringData:
  MONGO_URI: "${MONGO_URI}"
EOF

echo ""
echo "✅ Secret mongodb-atlas-secret criado/atualizado com sucesso!"
echo ""
echo "📋 Para verificar:"
echo "   kubectl get secret mongodb-atlas-secret"
echo "   kubectl get secret mongodb-atlas-secret -o jsonpath='{.data.MONGO_URI}' | base64 -d | head -c 50"
