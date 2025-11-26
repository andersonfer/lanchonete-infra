# Ajustes para Infraestrutura Repetível

Este documento lista os ajustes realizados para tornar o processo de deploy 100% automatizado e repetível.

---

## ✅ Ajustes Concluídos

### 1. `k8s/shared-rabbitmq-statefulset.yaml`
- Alterado `storageClassName: standard` para `storageClassName: gp2` (EKS)
- Alterado volume para `emptyDir: {}` (simplificação para PoC)

### 2. `terraform/kubernetes/main.tf`
- Adicionada regra de Security Group `lb_http` para porta 8080

### 3. `k8s/service.yaml` (4 repositórios)
- Alterado `type: ClusterIP` para `type: LoadBalancer`
- Alterado `port: 8080` para `port: 80`

### 4. `k8s/.env.secrets`
- Alinhado RabbitMQ para `admin/admin123`

### 5. `scripts/create-secrets.sh`
- Atualizado para ler senhas do Terraform automaticamente

### 6. `terraform/api-gateway/main.tf`
- Corrigido path duplicado nas integrações HTTP
- Antes: `${var.clientes_service_url}/clientes/{proxy}`
- Depois: `${var.clientes_service_url}/{proxy}`

### 7. Scripts de automação criados
- `scripts/deploy-infra.sh` - Deploy completo da infraestrutura
- `scripts/update-lambda-url.sh` - Atualiza Lambda com URL do clientes

---

## 📋 Ordem de Provisionamento

```
1. terraform/backend      (S3 + DynamoDB)
2. terraform/ecr          (Container Registry)
3. terraform/kubernetes   (EKS Cluster)
4. terraform/database     (RDS MySQL x3)
5. kubectl: secrets, RabbitMQ, MongoDB
6. Build & Push Images    (4 microserviços)
7. kubectl: Deployments, Services
8. terraform/auth         (Cognito)
9. terraform/lambda       (com URL vazia)
10. terraform/api-gateway (com URLs dos LBs)
11. update-lambda-url.sh  (atualiza Lambda)
```

---

## 🚀 Como Fazer Deploy

### Deploy Completo (nova infraestrutura)

```bash
# 1. Infraestrutura base (Terraform + k8s compartilhado)
./scripts/01-deploy-infra.sh

# 2. Build e push das imagens (todos os 4 serviços)
./scripts/02-build-and-push.sh

# 3. Aplicar deployments no Kubernetes
./scripts/03-deploy-k8s.sh

# 4. Aguardar Load Balancers (1-2 minutos)
kubectl get svc -w

# 5. Aplicar API Gateway (lê URLs automaticamente)
./scripts/04-apply-api-gateway.sh

# 6. Atualizar Lambda com URL do clientes
./scripts/05-update-lambda-url.sh
```

---

## ⚠️ Limitações Conhecidas

### AWS Load Balancer Controller
- Não instalado no EKS, então Ingress não funciona
- Usamos Services LoadBalancer que criam Classic ELBs
- Para usar ALB Ingress, instalar AWS LB Controller via Helm

### Dependência Lambda <-> Services
- Lambda precisa da URL do clientes, mas serviços precisam existir primeiro
- Solução atual: deploy em 2 fases + script `update-lambda-url.sh`

### Secrets
- Senhas RDS são geradas pelo Terraform
- Script `create-secrets.sh` lê do Terraform e cria no k8s
- Alternativa futura: External Secrets Operator + AWS Secrets Manager
