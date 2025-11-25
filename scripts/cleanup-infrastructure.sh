#!/bin/bash

# Script para limpar completamente a infraestrutura K8s
# CUIDADO: Remove todos os databases e dados!

set -e

echo "🗑️  LIMPEZA DA INFRAESTRUTURA"
echo "============================="
echo ""
echo "⚠️  ATENÇÃO: Este script vai deletar:"
echo "  - Todos os StatefulSets"
echo "  - Todos os PVCs (PERDA DE DADOS!)"
echo "  - Todos os Secrets"
echo "  - Todos os Services"
echo ""

read -p "Tem certeza? (digite 'sim' para confirmar): " confirm

if [ "$confirm" != "sim" ]; then
    echo "Cancelado."
    exit 0
fi

echo ""
echo "🗑️  Deletando databases..."
kubectl delete -f k8s/databases/ --ignore-not-found=true

echo ""
echo "🗑️  Deletando secrets..."
kubectl delete secret mysql-clientes-secret --ignore-not-found=true
kubectl delete secret mysql-pedidos-secret --ignore-not-found=true
kubectl delete secret mysql-cozinha-secret --ignore-not-found=true
kubectl delete secret mongodb-secret --ignore-not-found=true
kubectl delete secret rabbitmq-secret --ignore-not-found=true

echo ""
echo "🗑️  Deletando PVCs..."
kubectl delete pvc mysql-clientes-pvc --ignore-not-found=true
kubectl delete pvc mysql-pedidos-pvc --ignore-not-found=true
kubectl delete pvc mysql-cozinha-pvc --ignore-not-found=true
kubectl delete pvc mongodb-pvc --ignore-not-found=true
kubectl delete pvc rabbitmq-pvc --ignore-not-found=true

echo ""
echo "✅ Limpeza concluída!"
echo ""
echo "Para recriar a infraestrutura:"
echo "  ./scripts/test-infrastructure.sh"
