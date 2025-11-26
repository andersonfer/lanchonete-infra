#!/bin/bash

# Script para criar Secrets do Kubernetes para Microserviços
# Lê as senhas diretamente do Terraform state
# Uso: ./scripts/create-secrets.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"

echo "🔐 Criando Secrets do Kubernetes para Microserviços..."
echo ""

# Verificar se terraform está disponível
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform não encontrado. Instale o Terraform primeiro."
    exit 1
fi

# Verificar se jq está disponível
if ! command -v jq &> /dev/null; then
    echo "❌ jq não encontrado. Instale com: sudo apt install jq"
    exit 1
fi

# Ler senhas do módulo database
DATABASE_DIR="$INFRA_DIR/terraform/database"
if [ ! -d "$DATABASE_DIR" ]; then
    echo "❌ Diretório $DATABASE_DIR não encontrado"
    exit 1
fi

echo "📂 Lendo outputs do Terraform (database)..."
cd "$DATABASE_DIR"

# Extrair senhas do Terraform
MYSQL_CLIENTES_PASSWORD=$(terraform output -raw mysql_clientes_password 2>/dev/null || echo "")
MYSQL_PEDIDOS_PASSWORD=$(terraform output -raw mysql_pedidos_password 2>/dev/null || echo "")
MYSQL_COZINHA_PASSWORD=$(terraform output -raw mysql_cozinha_password 2>/dev/null || echo "")

# Extrair endpoints
MYSQL_CLIENTES_HOST=$(terraform output -raw mysql_clientes_endpoint 2>/dev/null | cut -d: -f1 || echo "")
MYSQL_PEDIDOS_HOST=$(terraform output -raw mysql_pedidos_endpoint 2>/dev/null | cut -d: -f1 || echo "")
MYSQL_COZINHA_HOST=$(terraform output -raw mysql_cozinha_endpoint 2>/dev/null | cut -d: -f1 || echo "")

if [ -z "$MYSQL_CLIENTES_PASSWORD" ]; then
    echo "❌ Não foi possível ler as senhas do Terraform."
    echo "   Verifique se o módulo database foi aplicado."
    exit 1
fi

echo "✅ Senhas lidas do Terraform com sucesso!"

# Valores fixos para MongoDB e RabbitMQ (não são gerenciados pelo Terraform)
MONGO_ROOT_PASSWORD="admin123"
MONGO_USER_PASSWORD="pagamento123"
RABBITMQ_PASSWORD="admin123"

echo ""
echo "🗑️  Removendo secrets antigos (se existirem)..."
kubectl delete secret mysql-clientes-secret --ignore-not-found=true
kubectl delete secret mysql-pedidos-secret --ignore-not-found=true
kubectl delete secret mysql-cozinha-secret --ignore-not-found=true
kubectl delete secret mongodb-secret --ignore-not-found=true
kubectl delete secret rabbitmq-secret --ignore-not-found=true

echo ""
echo "🔨 Criando novos secrets..."

# MySQL - Clientes
echo "  ✓ mysql-clientes-secret"
kubectl create secret generic mysql-clientes-secret \
  --from-literal=MYSQL_HOST="$MYSQL_CLIENTES_HOST" \
  --from-literal=MYSQL_DATABASE="clientes" \
  --from-literal=MYSQL_USER="clientes" \
  --from-literal=MYSQL_PASSWORD="$MYSQL_CLIENTES_PASSWORD"

# MySQL - Pedidos
echo "  ✓ mysql-pedidos-secret"
kubectl create secret generic mysql-pedidos-secret \
  --from-literal=MYSQL_HOST="$MYSQL_PEDIDOS_HOST" \
  --from-literal=MYSQL_DATABASE="pedidos" \
  --from-literal=MYSQL_USER="pedidos" \
  --from-literal=MYSQL_PASSWORD="$MYSQL_PEDIDOS_PASSWORD"

# MySQL - Cozinha
echo "  ✓ mysql-cozinha-secret"
kubectl create secret generic mysql-cozinha-secret \
  --from-literal=MYSQL_HOST="$MYSQL_COZINHA_HOST" \
  --from-literal=MYSQL_DATABASE="cozinha" \
  --from-literal=MYSQL_USER="cozinha" \
  --from-literal=MYSQL_PASSWORD="$MYSQL_COZINHA_PASSWORD"

# MongoDB - Pagamento
echo "  ✓ mongodb-secret"
kubectl create secret generic mongodb-secret \
  --from-literal=MONGO_INITDB_ROOT_USERNAME="admin" \
  --from-literal=MONGO_INITDB_ROOT_PASSWORD="$MONGO_ROOT_PASSWORD" \
  --from-literal=MONGO_USERNAME="pagamento" \
  --from-literal=MONGO_PASSWORD="$MONGO_USER_PASSWORD" \
  --from-literal=MONGO_INITDB_DATABASE="pagamentos"

# RabbitMQ
echo "  ✓ rabbitmq-secret"
kubectl create secret generic rabbitmq-secret \
  --from-literal=RABBITMQ_DEFAULT_USER="admin" \
  --from-literal=RABBITMQ_DEFAULT_PASS="$RABBITMQ_PASSWORD"

echo ""
echo "✅ Todos os secrets foram criados com sucesso!"
echo ""
echo "📋 Resumo dos secrets:"
kubectl get secrets | grep -E "(mysql-|mongodb-|rabbitmq-)"
