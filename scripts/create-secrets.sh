#!/bin/bash

# Script para criar Secrets do Kubernetes para Microserviços
# Uso: ./scripts/create-secrets.sh
#
# Carrega senhas de variáveis de ambiente ou usa valores padrão (desenvolvimento local)
# Para produção, exporte as variáveis antes de executar:
#   export MYSQL_ROOT_PASSWORD="senha-forte"
#   export MYSQL_CLIENTES_PASSWORD="senha-forte"
#   ...
#   ./scripts/create-secrets.sh

set -e

echo "🔐 Criando Secrets do Kubernetes para Microserviços..."
echo ""

# Carregar .env se existir (desenvolvimento local)
if [ -f .env ]; then
    echo "📝 Carregando variáveis de .env"
    export $(cat .env | grep -v '^#' | xargs)
fi

# Definir senhas com fallback para desenvolvimento
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-root123}"
MYSQL_CLIENTES_PASSWORD="${MYSQL_CLIENTES_PASSWORD:-clientes123}"
MYSQL_PEDIDOS_PASSWORD="${MYSQL_PEDIDOS_PASSWORD:-pedidos123}"
MYSQL_COZINHA_PASSWORD="${MYSQL_COZINHA_PASSWORD:-cozinha123}"
MONGO_PASSWORD="${MONGO_PASSWORD:-mongo123}"
RABBITMQ_PASSWORD="${RABBITMQ_PASSWORD:-rabbitmq123}"

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
  --from-literal=MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" \
  --from-literal=MYSQL_DATABASE="clientes_db" \
  --from-literal=MYSQL_USER="clientes_user" \
  --from-literal=MYSQL_PASSWORD="$MYSQL_CLIENTES_PASSWORD"

# MySQL - Pedidos
echo "  ✓ mysql-pedidos-secret"
kubectl create secret generic mysql-pedidos-secret \
  --from-literal=MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" \
  --from-literal=MYSQL_DATABASE="pedidos_db" \
  --from-literal=MYSQL_USER="pedidos_user" \
  --from-literal=MYSQL_PASSWORD="$MYSQL_PEDIDOS_PASSWORD"

# MySQL - Cozinha
echo "  ✓ mysql-cozinha-secret"
kubectl create secret generic mysql-cozinha-secret \
  --from-literal=MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" \
  --from-literal=MYSQL_DATABASE="cozinha_db" \
  --from-literal=MYSQL_USER="cozinha_user" \
  --from-literal=MYSQL_PASSWORD="$MYSQL_COZINHA_PASSWORD"

# MongoDB - Pagamento
echo "  ✓ mongodb-secret"
kubectl create secret generic mongodb-secret \
  --from-literal=MONGO_INITDB_ROOT_USERNAME="admin" \
  --from-literal=MONGO_INITDB_ROOT_PASSWORD="$MONGO_PASSWORD" \
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

echo ""
echo "🔍 Para verificar um secret específico:"
echo "   kubectl describe secret mysql-clientes-secret"
echo "   kubectl get secret mysql-clientes-secret -o yaml"
