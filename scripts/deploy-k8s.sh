#!/bin/bash

# Script para aplicar manifests Kubernetes no cluster
# Uso: ./scripts/deploy-k8s.sh

set -e

echo "🚀 Iniciando deploy no Kubernetes..."

echo "🔍 Verificando conexão com cluster..."
kubectl cluster-info --context $(kubectl config current-context) | head -1

echo "📦 Aplicando ConfigMaps..."
kubectl apply -f k8s_manifests/autoatendimento/autoatendimento-configmap.yaml
kubectl apply -f k8s_manifests/pagamento/pagamento-configmap.yaml

echo "🚀 Aplicando Deployments..."
kubectl apply -f k8s_manifests/autoatendimento/autoatendimento-deployment.yaml
kubectl apply -f k8s_manifests/pagamento/pagamento-deployment.yaml

echo "🌐 Aplicando Services..."
kubectl apply -f k8s_manifests/autoatendimento/autoatendimento-service.yml
kubectl apply -f k8s_manifests/pagamento/pagamento-service.yaml

echo "📈 Aplicando HPAs..."
kubectl apply -f k8s_manifests/autoatendimento/autoatendimento-hpa.yml
kubectl apply -f k8s_manifests/pagamento/pagamento-hpa.yml

echo "🔗 Aplicando Ingresses (ALB)..."
kubectl apply -f k8s_manifests/autoatendimento/autoatendimento-ingress.yaml
kubectl apply -f k8s_manifests/pagamento/pagamento-ingress.yaml

echo "⏳ Aguardando pods ficarem prontos..."
echo "  Aguardando autoatendimento..."
kubectl wait --for=condition=available --timeout=300s deployment/autoatendimento-deployment

echo "  Aguardando pagamento..."
kubectl wait --for=condition=available --timeout=300s deployment/pagamento-deployment

echo "✅ Deploy completo!"

echo "📋 Status dos recursos:"
echo ""
echo "🏗️  DEPLOYMENTS:"
kubectl get deployments -o wide

echo ""
echo "🌐 SERVICES:"
kubectl get services -o wide

echo ""
echo "📦 PODS:"
kubectl get pods -o wide

echo ""
echo "📈 HPAs:"
kubectl get hpa

echo ""
echo "🔗 INGRESSES (ALB):"
kubectl get ingress -o wide

echo ""
echo "🎯 Para acessar as aplicações via ALB:"
echo "  Aguarde 5-10 minutos para os ALBs ficarem ativos..."
echo "  Autoatendimento: http://$(kubectl get ingress autoatendimento-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo '[AGUARDANDO ALB...]')"
echo "  Pagamento: http://$(kubectl get ingress pagamento-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo '[AGUARDANDO ALB...]')"

echo ""
echo "⏳ Aguarde os ALBs ficarem ativos (pode demorar alguns minutos)..."
echo "   Use: watch -n 30 'kubectl get ingress'"

echo "📋 Deploy finalizado com sucesso!"