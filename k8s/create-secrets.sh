#!/bin/bash

# Script para criar secrets do Kubernetes a partir de arquivo .env

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env.secrets"
EXAMPLE_FILE="$SCRIPT_DIR/.env.secrets.example"

# Verificar se .env.secrets existe, senão copiar do exemplo
if [ ! -f "$ENV_FILE" ]; then
    echo "Arquivo .env.secrets nao encontrado."
    echo "Copiando de .env.secrets.example..."
    cp "$EXAMPLE_FILE" "$ENV_FILE"
    echo "AVISO: Arquivo .env.secrets criado com valores de exemplo."
    echo "Edite $ENV_FILE se necessario antes de continuar."
    echo ""
fi

# Carregar variáveis do arquivo
echo "Carregando variaveis de $ENV_FILE..."
source "$ENV_FILE"

echo ""
echo "Criando secrets no Kubernetes..."

# MongoDB Secret
echo "Criando mongodb-secret..."
kubectl create secret generic mongodb-secret \
  --from-literal=MONGO_INITDB_ROOT_USERNAME="$MONGO_INITDB_ROOT_USERNAME" \
  --from-literal=MONGO_INITDB_ROOT_PASSWORD="$MONGO_INITDB_ROOT_PASSWORD" \
  --from-literal=MONGO_USERNAME="$MONGO_USERNAME" \
  --from-literal=MONGO_PASSWORD="$MONGO_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

# MySQL Clientes Secret
echo "Criando mysql-clientes-secret..."
kubectl create secret generic mysql-clientes-secret \
  --from-literal=MYSQL_ROOT_PASSWORD="$MYSQL_CLIENTES_ROOT_PASSWORD" \
  --from-literal=MYSQL_DATABASE="$MYSQL_CLIENTES_DATABASE" \
  --from-literal=MYSQL_USER="$MYSQL_CLIENTES_USER" \
  --from-literal=MYSQL_PASSWORD="$MYSQL_CLIENTES_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

# MySQL Cozinha Secret
echo "Criando mysql-cozinha-secret..."
kubectl create secret generic mysql-cozinha-secret \
  --from-literal=MYSQL_ROOT_PASSWORD="$MYSQL_COZINHA_ROOT_PASSWORD" \
  --from-literal=MYSQL_DATABASE="$MYSQL_COZINHA_DATABASE" \
  --from-literal=MYSQL_USER="$MYSQL_COZINHA_USER" \
  --from-literal=MYSQL_PASSWORD="$MYSQL_COZINHA_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

# MySQL Pedidos Secret
echo "Criando mysql-pedidos-secret..."
kubectl create secret generic mysql-pedidos-secret \
  --from-literal=MYSQL_ROOT_PASSWORD="$MYSQL_PEDIDOS_ROOT_PASSWORD" \
  --from-literal=MYSQL_DATABASE="$MYSQL_PEDIDOS_DATABASE" \
  --from-literal=MYSQL_USER="$MYSQL_PEDIDOS_USER" \
  --from-literal=MYSQL_PASSWORD="$MYSQL_PEDIDOS_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

# RabbitMQ Secret
echo "Criando rabbitmq-secret..."
kubectl create secret generic rabbitmq-secret \
  --from-literal=RABBITMQ_DEFAULT_USER="$RABBITMQ_DEFAULT_USER" \
  --from-literal=RABBITMQ_DEFAULT_PASS="$RABBITMQ_DEFAULT_PASS" \
  --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "Secrets criados com sucesso!"
