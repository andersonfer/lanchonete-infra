#!/bin/bash

# Script para criar Secrets do Kubernetes para Microserviços
# Lê os valores diretamente do Terraform state (database module)
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

# Ler outputs do módulo database
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

# Extrair endpoints (host sem porta)
MYSQL_CLIENTES_HOST=$(terraform output -raw mysql_clientes_address 2>/dev/null || echo "")
MYSQL_PEDIDOS_HOST=$(terraform output -raw mysql_pedidos_address 2>/dev/null || echo "")
MYSQL_COZINHA_HOST=$(terraform output -raw mysql_cozinha_address 2>/dev/null || echo "")

# Extrair usernames do Terraform
MYSQL_CLIENTES_USER=$(terraform output -raw mysql_clientes_username 2>/dev/null || echo "admin")
MYSQL_PEDIDOS_USER=$(terraform output -raw mysql_pedidos_username 2>/dev/null || echo "admin")
MYSQL_COZINHA_USER=$(terraform output -raw mysql_cozinha_username 2>/dev/null || echo "admin")

# Extrair databases do Terraform
MYSQL_CLIENTES_DB=$(terraform output -raw mysql_clientes_database 2>/dev/null || echo "clientes_db")
MYSQL_PEDIDOS_DB=$(terraform output -raw mysql_pedidos_database 2>/dev/null || echo "pedidos_db")
MYSQL_COZINHA_DB=$(terraform output -raw mysql_cozinha_database 2>/dev/null || echo "cozinha_db")

if [ -z "$MYSQL_CLIENTES_PASSWORD" ]; then
    echo "❌ Não foi possível ler as senhas do Terraform."
    echo "   Verifique se o módulo database foi aplicado."
    exit 1
fi

echo "✅ Dados lidos do Terraform com sucesso!"
echo ""
echo "  Clientes: $MYSQL_CLIENTES_HOST (user: $MYSQL_CLIENTES_USER, db: $MYSQL_CLIENTES_DB)"
echo "  Pedidos:  $MYSQL_PEDIDOS_HOST (user: $MYSQL_PEDIDOS_USER, db: $MYSQL_PEDIDOS_DB)"
echo "  Cozinha:  $MYSQL_COZINHA_HOST (user: $MYSQL_COZINHA_USER, db: $MYSQL_COZINHA_DB)"

# Valores fixos para RabbitMQ (não são gerenciados pelo Terraform)
# NOTA: MongoDB agora usa Atlas (gerenciado via create-atlas-secret.sh)
RABBITMQ_PASSWORD="admin123"

echo ""
echo "🗑️  Removendo secrets antigos (se existirem)..."
kubectl delete secret mysql-clientes-secret --ignore-not-found=true
kubectl delete secret mysql-pedidos-secret --ignore-not-found=true
kubectl delete secret mysql-cozinha-secret --ignore-not-found=true
kubectl delete secret rabbitmq-secret --ignore-not-found=true
# NOTA: mongodb-atlas-secret é gerenciado pelo create-atlas-secret.sh

echo ""
echo "🔨 Criando novos secrets..."

# MySQL - Clientes
echo "  ✓ mysql-clientes-secret"
kubectl create secret generic mysql-clientes-secret \
  --from-literal=MYSQL_HOST="$MYSQL_CLIENTES_HOST" \
  --from-literal=MYSQL_PORT="3306" \
  --from-literal=MYSQL_DATABASE="$MYSQL_CLIENTES_DB" \
  --from-literal=MYSQL_USER="$MYSQL_CLIENTES_USER" \
  --from-literal=MYSQL_PASSWORD="$MYSQL_CLIENTES_PASSWORD"

# MySQL - Pedidos
echo "  ✓ mysql-pedidos-secret"
kubectl create secret generic mysql-pedidos-secret \
  --from-literal=MYSQL_HOST="$MYSQL_PEDIDOS_HOST" \
  --from-literal=MYSQL_PORT="3306" \
  --from-literal=MYSQL_DATABASE="$MYSQL_PEDIDOS_DB" \
  --from-literal=MYSQL_USER="$MYSQL_PEDIDOS_USER" \
  --from-literal=MYSQL_PASSWORD="$MYSQL_PEDIDOS_PASSWORD"

# MySQL - Cozinha
echo "  ✓ mysql-cozinha-secret"
kubectl create secret generic mysql-cozinha-secret \
  --from-literal=MYSQL_HOST="$MYSQL_COZINHA_HOST" \
  --from-literal=MYSQL_PORT="3306" \
  --from-literal=MYSQL_DATABASE="$MYSQL_COZINHA_DB" \
  --from-literal=MYSQL_USER="$MYSQL_COZINHA_USER" \
  --from-literal=MYSQL_PASSWORD="$MYSQL_COZINHA_PASSWORD"

# RabbitMQ
echo "  ✓ rabbitmq-secret"
kubectl create secret generic rabbitmq-secret \
  --from-literal=RABBITMQ_DEFAULT_USER="admin" \
  --from-literal=RABBITMQ_DEFAULT_PASS="$RABBITMQ_PASSWORD"

echo ""
echo "✅ Secrets MySQL e RabbitMQ criados com sucesso!"
echo ""

# Criar secret do MongoDB Atlas
echo "🔐 Criando secret do MongoDB Atlas..."
"$SCRIPT_DIR/create-atlas-secret.sh"

echo ""
echo "📋 Resumo dos secrets:"
kubectl get secrets | grep -E "(mysql-|mongodb-atlas-|rabbitmq-)"
