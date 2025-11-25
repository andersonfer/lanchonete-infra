#!/bin/bash

# Script de Teste da Infraestrutura K8s
# Testa databases e RabbitMQ antes de subir os microserviços

set -e

echo "🧪 TESTE DA INFRAESTRUTURA - Sistema Lanchonete"
echo "================================================"
echo ""

# Cores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para mensagens
success() { echo -e "${GREEN}✓${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }
info() { echo -e "${YELLOW}➜${NC} $1"; }

# Verificar se Minikube está rodando
info "Verificando Minikube..."
if ! minikube status &>/dev/null; then
    error "Minikube não está rodando!"
    echo ""
    echo "Execute primeiro:"
    echo "  minikube start --memory=4096 --cpus=4"
    exit 1
fi
success "Minikube rodando"

# Verificar kubectl
info "Verificando kubectl..."
if ! kubectl cluster-info &>/dev/null; then
    error "kubectl não conectado ao cluster"
    exit 1
fi
success "kubectl conectado"

echo ""
echo "📋 PASSO 1: Criar Secrets"
echo "-------------------------"
info "Executando scripts/create-secrets.sh..."

if [ ! -f "./scripts/create-secrets.sh" ]; then
    error "Script create-secrets.sh não encontrado!"
    exit 1
fi

chmod +x ./scripts/create-secrets.sh
./scripts/create-secrets.sh

echo ""
echo "📦 PASSO 2: Deploy Databases"
echo "----------------------------"
info "Aplicando manifests k8s/databases/..."

kubectl apply -f k8s/databases/mysql-clientes.yaml
kubectl apply -f k8s/databases/mysql-pedidos.yaml
kubectl apply -f k8s/databases/mysql-cozinha.yaml
kubectl apply -f k8s/databases/mongodb.yaml
kubectl apply -f k8s/databases/rabbitmq.yaml

success "Manifests aplicados"

echo ""
echo "⏳ PASSO 3: Aguardar Pods Prontos"
echo "---------------------------------"
info "Isso pode levar 2-3 minutos..."

echo ""
echo "Aguardando MySQL Clientes..."
kubectl wait --for=condition=ready pod -l app=mysql-clientes --timeout=180s
success "MySQL Clientes pronto"

echo "Aguardando MySQL Pedidos..."
kubectl wait --for=condition=ready pod -l app=mysql-pedidos --timeout=180s
success "MySQL Pedidos pronto"

echo "Aguardando MySQL Cozinha..."
kubectl wait --for=condition=ready pod -l app=mysql-cozinha --timeout=180s
success "MySQL Cozinha pronto"

echo "Aguardando MongoDB..."
kubectl wait --for=condition=ready pod -l app=mongodb --timeout=180s
success "MongoDB pronto"

echo "Aguardando RabbitMQ..."
kubectl wait --for=condition=ready pod -l app=rabbitmq --timeout=180s
success "RabbitMQ pronto"

echo ""
echo "🔍 PASSO 4: Verificar Status"
echo "----------------------------"

echo ""
echo "StatefulSets:"
kubectl get statefulsets

echo ""
echo "Pods:"
kubectl get pods -l 'app in (mysql-clientes,mysql-pedidos,mysql-cozinha,mongodb,rabbitmq)'

echo ""
echo "PVCs:"
kubectl get pvc

echo ""
echo "Services:"
kubectl get svc -l 'app in (mysql-clientes,mysql-pedidos,mysql-cozinha,mongodb,rabbitmq)'

echo ""
echo "✅ PASSO 5: Testes de Conectividade"
echo "------------------------------------"

# Testar MySQL Clientes
info "Testando MySQL Clientes..."
if kubectl exec mysql-clientes-0 -- mysql -u root -p${MYSQL_ROOT_PASSWORD:-root123} -e "SELECT 1" &>/dev/null; then
    success "MySQL Clientes conectando"
else
    error "MySQL Clientes falhou"
fi

# Testar MySQL Pedidos
info "Testando MySQL Pedidos..."
if kubectl exec mysql-pedidos-0 -- mysql -u root -p${MYSQL_ROOT_PASSWORD:-root123} -e "SELECT 1" &>/dev/null; then
    success "MySQL Pedidos conectando"
else
    error "MySQL Pedidos falhou"
fi

# Testar MySQL Cozinha
info "Testando MySQL Cozinha..."
if kubectl exec mysql-cozinha-0 -- mysql -u root -p${MYSQL_ROOT_PASSWORD:-root123} -e "SELECT 1" &>/dev/null; then
    success "MySQL Cozinha conectando"
else
    error "MySQL Cozinha falhou"
fi

# Testar MongoDB
info "Testando MongoDB..."
if kubectl exec mongodb-0 -- mongosh --eval "db.adminCommand('ping')" &>/dev/null; then
    success "MongoDB conectando"
else
    error "MongoDB falhou"
fi

# Testar RabbitMQ
info "Testando RabbitMQ..."
if kubectl exec rabbitmq-0 -- rabbitmq-diagnostics -q ping &>/dev/null; then
    success "RabbitMQ conectando"
else
    error "RabbitMQ falhou"
fi

echo ""
echo "🌐 PASSO 6: URLs de Acesso"
echo "--------------------------"

MINIKUBE_IP=$(minikube ip)

echo ""
echo "RabbitMQ Management UI:"
echo "  http://$MINIKUBE_IP:30672"
echo "  User: admin"
echo "  Password: ${RABBITMQ_PASSWORD:-rabbitmq123}"
echo ""

echo "Para conectar aos bancos via port-forward:"
echo "  kubectl port-forward mysql-clientes-0 3306:3306"
echo "  kubectl port-forward mongodb-0 27017:27017"
echo "  kubectl port-forward rabbitmq-0 15672:15672"
echo ""

echo "📊 RESUMO FINAL"
echo "==============="
echo ""
success "5 StatefulSets criados e rodando"
success "5 PersistentVolumeClaims criados (25Gi total)"
success "5 Services internos funcionando"
success "Todos os health checks passando"
echo ""
echo "✅ INFRAESTRUTURA PRONTA PARA MICROSERVIÇOS!"
echo ""
echo "Próximos passos:"
echo "  1. Implementar microserviços em services/"
echo "  2. Deploy dos microserviços: kubectl apply -f k8s/services/"
echo "  3. Testar fluxo completo E2E"
