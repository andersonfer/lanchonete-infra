# Ajustes Necessários para Infraestrutura Repetível

Este documento lista todos os ajustes manuais realizados durante o deploy da infraestrutura que precisam ser incorporados ao código para tornar o processo 100% automatizado.

---

## 1. Arquivos Modificados (não commitados)

### 1.1 `k8s/shared-rabbitmq-statefulset.yaml`

**Problema**: StorageClass "standard" não existe no EKS (é do Minikube). EKS usa "gp2".

**Solução aplicada manualmente**:
- Alterado `storageClassName: standard` para `storageClassName: gp2`
- Alterado volume de `persistentVolumeClaim` para `emptyDir: {}` (simplificação para PoC)

**Ação necessária**: Commitar a alteração ou criar arquivo separado para AWS.

---

### 1.2 `terraform/kubernetes/main.tf`

**Problema**: Faltava regra de Security Group para permitir tráfego na porta 8080 (usada pelos Services LoadBalancer).

**Solução aplicada manualmente**: Adicionada regra `lb_http` para porta 8080.

**Ação necessária**: Commitar a alteração.

---

### 1.3 `k8s/service.yaml` (todos os 4 microserviços)

**Problema**: Services estavam como `ClusterIP`, mas para expor externamente sem AWS Load Balancer Controller, precisam ser `LoadBalancer`.

**Solução aplicada manualmente**:
- Alterado `type: ClusterIP` para `type: LoadBalancer`
- Alterado `port: 8080` para `port: 80` (padrão HTTP)

**Ação necessária**: Commitar as alterações nos 4 repositórios:
- lanchonete-clientes
- lanchonete-pagamento
- lanchonete-pedidos
- lanchonete-cozinha

---

## 2. Ajustes Manuais via kubectl/AWS CLI

### 2.1 Secrets do Kubernetes

**Problema**: As senhas dos bancos RDS são geradas aleatoriamente pelo Terraform, mas os secrets do k8s estavam com senhas hardcoded.

**Solução aplicada manualmente**:
```bash
# Extrair senhas do Terraform state
cd terraform/database && terraform output -json

# Recriar secrets com senhas corretas
kubectl delete secret mysql-clientes-secret mysql-pedidos-secret mysql-cozinha-secret
kubectl create secret generic mysql-clientes-secret --from-literal=...
```

**Ação necessária**: Criar script que:
1. Lê as senhas do `terraform output`
2. Cria os secrets automaticamente

Ou usar **External Secrets Operator** / **AWS Secrets Manager** para sincronizar.

---

### 2.2 RabbitMQ Secret

**Problema**: ConfigMaps dos serviços usam `RABBITMQ_USERNAME: "admin"`, mas o secret original usava `guest`.

**Solução aplicada manualmente**:
```bash
kubectl delete secret rabbitmq-secret
kubectl create secret generic rabbitmq-secret \
  --from-literal=RABBITMQ_DEFAULT_USER=admin \
  --from-literal=RABBITMQ_DEFAULT_PASS=admin123
```

**Ação necessária**:
- Alinhar credenciais entre `k8s/.env.secrets` e os ConfigMaps dos serviços
- Ou usar valores consistentes em ambos

---

### 2.3 Lambda - CLIENTES_SERVICE_URL

**Problema**: A Lambda foi provisionada antes dos Load Balancers existirem, então `CLIENTES_SERVICE_URL` ficou vazia.

**Solução aplicada manualmente**:
```bash
aws lambda update-function-configuration \
  --function-name lanchonete-auth-lambda \
  --environment 'Variables={...,CLIENTES_SERVICE_URL=http://<elb-dns>}'
```

**Ação necessária**: Criar dependência correta no Terraform:
1. Opção A: Deploy da Lambda DEPOIS dos microserviços (workflow separado)
2. Opção B: Usar Service Discovery (Cloud Map) ao invés de URLs fixas
3. Opção C: Criar API Gateway primeiro como entry point único

---

## 3. Integração API Gateway com Microserviços

### 3.1 Problema Identificado

O API Gateway está retornando erro 500 ao tentar acessar os endpoints dos microserviços, mesmo com token válido:

```bash
# Endpoint público funciona:
curl -X POST "$API_URL/auth/identificar" -d '{"cpf":"12345678900"}'
# Retorna: {"accessToken":"...", "tipo":"IDENTIFICADO"}

# Endpoints protegidos falham:
curl "$API_URL/clientes/actuator/health" -H "Authorization: $TOKEN"
# Retorna: {"mensagem":"Erro interno do servidor","status":500}

# Mas acessando direto no Load Balancer funciona:
curl "http://<elb-dns>/actuator/health"
# Retorna: {"status":"UP",...}
```

### 3.2 Causa Provável

A integração HTTP do API Gateway com os microserviços está com problema de configuração. Possíveis causas:
- Path mapping incorreto (duplicação de path)
- Configuração de integração HTTP_PROXY
- Timeout ou headers não propagados

### 3.3 Ação Necessária

Investigar o módulo `terraform/api-gateway/main.tf`:
1. Verificar se o path está sendo duplicado (ex: `/clientes/actuator/health` virando `/clientes/clientes/actuator/health`)
2. Verificar configuração de `integration_http_method`
3. Verificar se `uri` da integração está correto
4. Adicionar logs no API Gateway para debug

### 3.4 Teste de Diagnóstico

```bash
# Verificar como o API Gateway está montando a URL
aws apigateway get-integration \
  --rest-api-id <api-id> \
  --resource-id <resource-id> \
  --http-method GET
```

---

## 4. Ordem de Provisionamento

A ordem correta de provisionamento deve ser:

```
1. terraform/backend      (S3 + DynamoDB)
2. terraform/ecr          (Container Registry)
3. terraform/kubernetes   (EKS Cluster)
4. terraform/database     (RDS MySQL x3)
5. kubectl apply          (Secrets, RabbitMQ, MongoDB)
6. Build & Push Images    (4 microserviços)
7. kubectl apply          (Deployments, Services)
8. terraform/auth         (Cognito)
9. terraform/lambda       (com CLIENTES_SERVICE_URL dos LBs)
10. terraform/api-gateway (com URLs dos LBs)
```

**Ação necessária**: Criar script de orquestração ou pipeline que respeite essa ordem.

---

## 5. Scripts Recomendados

### 5.1 `scripts/deploy-infra.sh`
Script que executa todos os Terraform na ordem correta.

### 5.2 `scripts/create-k8s-secrets.sh`
Script que lê senhas do Terraform e cria secrets no k8s.

### 5.3 `scripts/deploy-services.sh`
Script que faz build, push e apply dos 4 microserviços.

### 5.4 `scripts/update-lambda-urls.sh`
Script que atualiza a Lambda com as URLs dos Load Balancers.

---

## 6. Problemas Arquiteturais a Resolver

### 6.1 AWS Load Balancer Controller
O EKS não tem o AWS Load Balancer Controller instalado, então Ingress não funciona.

**Opções**:
- A) Continuar usando Services LoadBalancer (atual) - cria Classic ELBs
- B) Instalar AWS LB Controller via Helm - permite usar ALB Ingress
- C) Usar NodePort + API Gateway direto

### 6.2 Secrets Management
Atualmente secrets são criados manualmente.

**Opções**:
- A) External Secrets Operator + AWS Secrets Manager
- B) Sealed Secrets
- C) Script que sincroniza Terraform outputs -> k8s secrets

### 6.3 Dependência Circular Lambda <-> Services
Lambda precisa da URL do serviço de clientes, mas serviços precisam existir primeiro.

**Opções**:
- A) Deploy em 2 fases (infra básica -> serviços -> lambda/api-gateway)
- B) Usar Service Discovery (AWS Cloud Map)
- C) Usar DNS fixo com Route53

---

## 7. Checklist para Próximo Deploy

- [ ] Commitar alterações em `k8s/shared-rabbitmq-statefulset.yaml`
- [ ] Commitar alterações em `terraform/kubernetes/main.tf`
- [ ] Commitar alterações em `k8s/service.yaml` (4 repos)
- [ ] Criar script `create-k8s-secrets.sh` que lê do Terraform
- [ ] Alinhar credenciais RabbitMQ (admin/admin123)
- [ ] Corrigir integração API Gateway -> Microserviços
- [ ] Documentar ordem de provisionamento
- [ ] Criar script de deploy unificado
