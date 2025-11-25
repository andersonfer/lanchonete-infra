# 📋 FASE A - MIGRAÇÃO PARA AWS EKS

**Projeto:** Sistema de Lanchonete - Migração AWS
**Última Atualização:** 2025-10-27
**Status:** ✅ **CONCLUÍDA COM SUCESSO** - 100% Operacional

---

---

## 🎉 RESULTADO FINAL (2025-10-27)

### ✅ Infraestrutura AWS Provisionada
- **Cluster EKS:** lanchonete-cluster (2 nós t3.medium) - ✅ RODANDO
- **RDS MySQL:** 3 instâncias db.t3.micro - ✅ CONECTADAS
- **MongoDB:** StatefulSet com emptyDir - ✅ RODANDO
- **RabbitMQ:** StatefulSet com emptyDir - ✅ RODANDO
- **ECR:** 4 repositórios com imagens - ✅ ATUALIZADOS
- **LoadBalancers:** 4 Network Load Balancers - ✅ PROVISIONADOS

### ✅ Microserviços Deployados
- **Clientes:** 1/1 Running, conectado RDS MySQL ✅
- **Pedidos:** 1/1 Running, conectado RDS MySQL + RabbitMQ + Feign ✅
- **Cozinha:** 1/1 Running, conectado RDS MySQL + RabbitMQ + Feign ✅
- **Pagamento:** 1/1 Running, conectado MongoDB + RabbitMQ ✅

### ✅ Testes E2E AWS
- **TESTE 1:** Pedido Anônimo - ✅ PASSOU
- **TESTE 2:** Pedido com CPF (Feign Client) - ✅ PASSOU
- **TESTE 3:** Edge Cases e Erros - ✅ PASSOU
- **Pagamento Rejeitado:** ✅ VALIDADO (pedido cancelado)
- **Taxa de sucesso:** 100% (todos os testes passaram)

### ✅ Como Obter URLs de Produção (Dinâmico)
```bash
# Obter todas as URLs LoadBalancer
kubectl get svc -o wide | grep LoadBalancer

# Obter URL específica de um serviço
kubectl get svc clientes-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
kubectl get svc pedidos-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
kubectl get svc cozinha-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
kubectl get svc pagamento-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

**NOTA:** URLs mudam a cada redeploy dos Services. Sempre usar comandos acima para obter URLs atualizadas.

---

## 🎯 OBJETIVO DA FASE A

Migrar toda a infraestrutura de microserviços do Minikube local para AWS EKS, aproveitando **~75% da infraestrutura Terraform já existente** no projeto.

**RESULTADO:** ✅ Objetivo alcançado com 100% de sucesso.

---

## 📊 ANÁLISE DE REAPROVEITAMENTO

### ✅ O QUE JÁ EXISTE E PODE SER REAPROVEITADO (75%)

#### 1. **Backend Terraform (100% PRONTO)** ✅
- **Local:** `infra/backend/`
- **Status:** Já provisionado e funcional
- S3 bucket: `lanchonete-terraform-state-poc`
- DynamoDB: `lanchonete-terraform-locks`
- **Ação:** Nenhuma - apenas usar

#### 2. **ECR Repositories (70% PRONTO)** ✅
- **Local:** `infra/ecr/`
- **Provisionado:**
  - `lanchonete-autoatendimento`
  - `lanchonete-pagamento`
- **Faltando:**
  - `lanchonete-clientes`
  - `lanchonete-pedidos`
  - `lanchonete-cozinha`
- **Ação:** Adicionar 3 repositórios (15 minutos)

#### 3. **Terraform EKS (70% PRONTO)** ✅
- **Local:** `infra/kubernetes/`
- **Configuração:**
  - EKS cluster versão 1.28
  - Node groups (t3.medium, 2-4 nodes)
  - Security groups
  - **Limitação:** Usa LabRole (AWS Academy)
- **Ação:** Validar e aplicar (já compatível com AWS Academy)

#### 4. **AWS Load Balancer Controller (90% PRONTO)** ✅
- **Local:** `infra/ingress/`
- **Configuração:**
  - Helm chart v1.6.2
  - ServiceAccount
  - Subnet tags corretas
- **Ação:** Aplicar após EKS estar rodando

#### 5. **Manifestos Kubernetes Otimizados (85% PRONTO)** ✅
- **Local:** `k8s_manifests/` e `k8s/`
- **Recursos:**
  - Deployments com health checks escalonados
  - HPAs configurados (min: 2, max: 4)
  - ConfigMaps otimizados
  - StatefulSets (MySQL x3, MongoDB, RabbitMQ)
- **Ação:** Adaptar secrets e variáveis de ambiente

#### 6. **Cognito + Lambda (COMPLETO)** ✅
- **Local:** `infra/auth/`, `infra/lambda/`, `infra/api-gateway/`
- **Configuração:**
  - User Pool configurado
  - Lambda de autenticação (Java 17)
  - API Gateway com rotas
- **Ação:** Aplicar após EKS e Ingress

#### 7. **Dockerfiles (40% PRONTO)** ⚠️
- **Existentes:**
  - `app/autoatendimento/Dockerfile` ✅
  - `app/pagamento/Dockerfile` ✅
- **Faltando:**
  - `services/clientes/Dockerfile` ❌
  - `services/pedidos/Dockerfile` ❌
  - `services/cozinha/Dockerfile` ❌
- **Ação:** Criar 3 Dockerfiles (30 minutos - copiar template existente)

### ❌ O QUE PRECISA SER CRIADO (25%)

1. **3 Repositórios ECR** (clientes, pedidos, cozinha)
2. **3 Dockerfiles** (clientes, pedidos, cozinha)
3. **Adaptações de Secrets** (ConfigMaps e Secrets K8s)

---

## 🏗️ ARQUITETURA AWS FINAL

```
┌─────────────────────────────────────────────────────┐
│                  AWS Cloud                          │
│                                                     │
│  ┌──────────────────────────────────────────────┐  │
│  │         Application Load Balancer            │  │ ← Terraform pronto
│  │              (via Ingress)                   │  │
│  └──────────────────────────────────────────────┘  │
│                        ↓                            │
│  ┌──────────────────────────────────────────────┐  │
│  │         EKS Cluster (1.28)                   │  │ ← Terraform pronto
│  │  ┌────────┐ ┌────────┐ ┌────────┐           │  │
│  │  │Clientes│ │ Pedidos│ │Cozinha │           │  │
│  │  └────────┘ └────────┘ └────────┘           │  │
│  │  ┌────────┐ ┌────────┐                      │  │
│  │  │Autoat. │ │Pagam.  │                      │  │
│  │  └────────┘ └────────┘                      │  │
│  │                                              │  │
│  │  StatefulSets (mantidos do Minikube):       │  │
│  │  ┌──────────────────────────────────┐       │  │
│  │  │ MySQL x3 + MongoDB + RabbitMQ    │       │  │
│  │  └──────────────────────────────────┘       │  │
│  └──────────────────────────────────────────────┘  │
│                                                     │
│  ┌──────────────────────────────────────────────┐  │
│  │  ECR Repositories (5 total)                  │  │
│  │  ✅ autoatendimento, pagamento               │  │
│  │  ❌ clientes, pedidos, cozinha (criar)       │  │
│  └──────────────────────────────────────────────┘  │
│                                                     │
│  ┌──────────────────────────────────────────────┐  │
│  │  AWS Cognito (Auth)                          │  │ ← Terraform pronto
│  │  + Lambda + API Gateway                      │  │
│  └──────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘

VPC: Default (VPC padrão da AWS)
IAM: LabRole (AWS Academy)
Bancos: StatefulSets no K8s (não RDS)
```

---

## ✅ DECISÕES ARQUITETURAIS

### 1. **Ambiente: AWS Academy** ✅
- Usar LabRole existente no Terraform
- Não criar IAM roles customizados
- Compatível com Terraform já configurado

### 2. **VPC: Default VPC** ✅
- Aceitar VPC padrão da AWS
- Mais rápido (1 dia economizado)
- Suficiente para POC/Fase 4

### 3. **Bancos de Dados: StatefulSets no EKS** ✅
- Manter MySQL x3, MongoDB e RabbitMQ como StatefulSets
- Mesmos manifestos que funcionam no Minikube
- Evita complexidade e custos de RDS/DocumentDB
- **Não usar** `infra/database/` (RDS)

### 4. **Autenticação: AWS Cognito** ✅
- Usar Terraform pronto em `infra/auth/`
- Integrar Lambda + API Gateway
- Proteger endpoints dos microserviços

---

## 📋 PLANO DE EXECUÇÃO FASE A

### **Tempo Total Estimado: 3-4 dias**

### **DIA 1: Preparação e ECR (4-6 horas)**

#### 1.1 Expandir Repositórios ECR (15 minutos)
**Local:** `infra/ecr/main.tf`

**Ação:**
```terraform
# Adicionar 3 novos recursos ECR:
resource "aws_ecr_repository" "clientes" { ... }
resource "aws_ecr_repository" "pedidos" { ... }
resource "aws_ecr_repository" "cozinha" { ... }
```

**Comando:**
```bash
cd infra/ecr
terraform plan
terraform apply
```

**Resultado esperado:**
- 5 repositórios ECR provisionados
- URLs dos repositórios anotadas

---

#### 1.2 Criar Dockerfiles Faltantes (30 minutos)
**Template base:** `app/autoatendimento/Dockerfile`

**Criar:**
1. `services/clientes/Dockerfile`
2. `services/pedidos/Dockerfile`
3. `services/cozinha/Dockerfile`

**Características:**
- Multi-stage build (Maven → JRE)
- Base: eclipse-temurin:17-jre
- Usuário não-root (appuser)
- JAVA_OPTS otimizados

---

#### 1.3 Build e Push de Imagens Docker (1-2 horas)
**Pré-requisito:** AWS CLI configurado

**Comandos:**
```bash
# Login no ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  339712817738.dkr.ecr.us-east-1.amazonaws.com

# Build e push de cada microserviço
cd services/clientes && docker build -t lanchonete-clientes:latest .
docker tag lanchonete-clientes:latest 339712817738.dkr.ecr.us-east-1.amazonaws.com/lanchonete-clientes:latest
docker push 339712817738.dkr.ecr.us-east-1.amazonaws.com/lanchonete-clientes:latest

# Repetir para pedidos, cozinha, autoatendimento, pagamento
```

**Resultado esperado:**
- 5 imagens Docker no ECR
- Tags `latest` atualizadas

---

### **DIA 2: Provisionamento EKS (6-8 horas)**

#### 2.1 Aplicar Terraform EKS (2-3 horas)
**Local:** `infra/kubernetes/main.tf`

**Pré-validação:**
```bash
cd infra/kubernetes
terraform init
terraform plan  # Revisar recursos
```

**Aplicar:**
```bash
terraform apply
# Aguardar ~15-20 minutos para cluster ficar pronto
```

**Recursos provisionados:**
- EKS cluster `lanchonete-cluster`
- Node group (2-4 nodes t3.medium)
- Security groups
- VPC endpoints

**Resultado esperado:**
- Cluster EKS ativo
- Nodes registrados

---

#### 2.2 Configurar kubectl (15 minutos)
```bash
# Configurar acesso ao cluster
aws eks update-kubeconfig \
  --region us-east-1 \
  --name lanchonete-cluster

# Validar
kubectl get nodes
kubectl get namespaces
```

---

#### 2.3 Aplicar Manifestos K8s - StatefulSets (1-2 horas)
**Local:** `k8s/statefulsets/`

**Ordem de aplicação:**
```bash
# 1. Secrets
kubectl create secret generic mysql-clientes-secret \
  --from-literal=MYSQL_ROOT_PASSWORD=rootpass123 \
  --from-literal=MYSQL_DATABASE=clientes_db \
  --from-literal=MYSQL_USER=clientes_user \
  --from-literal=MYSQL_PASSWORD=clientespass123

# Repetir para mysql-pedidos, mysql-cozinha, mongodb, rabbitmq

# 2. StatefulSets dos bancos
kubectl apply -f k8s/statefulsets/mysql-clientes-statefulset.yaml
kubectl apply -f k8s/statefulsets/mysql-pedidos-statefulset.yaml
kubectl apply -f k8s/statefulsets/mysql-cozinha-statefulset.yaml
kubectl apply -f k8s/statefulsets/mongodb-statefulset.yaml
kubectl apply -f k8s/statefulsets/rabbitmq-statefulset.yaml

# 3. Validar
kubectl get pods -w
# Aguardar todos os pods ficarem Running (5-10 min)
```

---

#### 2.4 Aplicar Manifestos K8s - Microserviços (1-2 horas)
**Local:** `k8s/deployments/`, `k8s/configmaps/`, `k8s/services/`

**Adaptar ConfigMaps:**
- Atualizar URLs ECR nas variáveis de ambiente
- Ajustar endpoints dos bancos (se necessário)

**Aplicar:**
```bash
# ConfigMaps
kubectl apply -f k8s/configmaps/

# Services (ClusterIP)
kubectl apply -f k8s/services/

# Deployments
kubectl apply -f k8s/deployments/

# HPAs
kubectl apply -f k8s/hpa/

# Validar
kubectl get pods
kubectl get svc
kubectl describe pod <pod-name>
```

**Resultado esperado:**
- 4 deployments rodando (2 réplicas cada)
- Todos os pods em status Running
- Health checks passando

---

### **DIA 3: Ingress e ALB (4-6 horas)**

#### 3.1 Aplicar AWS Load Balancer Controller (1-2 horas)
**Local:** `infra/ingress/main.tf`

**Pré-requisito:** EKS cluster rodando

**Aplicar:**
```bash
cd infra/ingress
terraform init
terraform plan
terraform apply
# Aguardar instalação do Helm chart (~5 min)
```

**Validar:**
```bash
kubectl get pods -n kube-system | grep aws-load-balancer
# Deve mostrar pod(s) do controller rodando
```

---

#### 3.2 Criar/Adaptar Ingress Resource (1 hora)
**Local:** `k8s/ingress/aws/`

**Opção 1: Reutilizar Ingress existente**
```bash
# Verificar ingress existentes
ls k8s_manifests/*/ingress.yaml

# Adaptar e aplicar
kubectl apply -f k8s_manifests/autoatendimento/autoatendimento-ingress.yaml
kubectl apply -f k8s_manifests/pagamento/pagamento-ingress.yaml
```

**Opção 2: Criar Ingress unificado**
```yaml
# k8s/ingress/aws/unified-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: lanchonete-ingress
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
          - path: /clientes
            pathType: Prefix
            backend:
              service:
                name: clientes-service
                port:
                  number: 8080
          - path: /pedidos
            pathType: Prefix
            backend:
              service:
                name: pedidos-service
                port:
                  number: 8080
          # ... outros serviços
```

**Aplicar:**
```bash
kubectl apply -f k8s/ingress/aws/unified-ingress.yaml
```

---

#### 3.3 Aguardar Provisionamento ALB (10-15 minutos)
```bash
kubectl get ingress -w
# Aguardar campo ADDRESS ser preenchido com URL do ALB
```

**Anotar URL do ALB:**
```bash
kubectl get ingress lanchonete-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
# Exemplo: a1b2c3-1234567890.us-east-1.elb.amazonaws.com
```

---

#### 3.4 Testar Endpoints via ALB (1-2 horas)
```bash
ALB_URL="http://$(kubectl get ingress lanchonete-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"

# Testar health checks
curl $ALB_URL/clientes/actuator/health
curl $ALB_URL/pedidos/actuator/health
curl $ALB_URL/cozinha/actuator/health
curl $ALB_URL/pagamento/actuator/health

# Testar endpoints funcionais
curl -X POST $ALB_URL/pedidos/pedidos \
  -H "Content-Type: application/json" \
  -d '{"cpfCliente": null, "itens": [{"produtoId": 1, "quantidade": 1}]}'
```

**Resultado esperado:**
- Todos os health checks retornam 200 OK
- Endpoints funcionais respondem corretamente

---

### **DIA 4: Cognito e Validação Final (4-6 horas)**

#### 4.1 Aplicar Terraform Cognito (30 minutos)
**Local:** `infra/auth/main.tf`

```bash
cd infra/auth
terraform init
terraform plan
terraform apply
```

**Anotar Outputs:**
```bash
terraform output
# user_pool_id
# user_pool_client_id
# user_pool_domain
```

---

#### 4.2 Aplicar Lambda de Autenticação (30 minutos)
**Local:** `infra/lambda/`

**Build do Lambda:**
```bash
cd infra/lambda
./build.sh  # Compila e cria lambda-auth.zip
```

**Aplicar Terraform:**
```bash
terraform init
terraform plan
terraform apply
```

---

#### 4.3 Aplicar API Gateway (1 hora)
**Local:** `infra/api-gateway/main.tf`

**Pré-requisito:**
- ALBs criados pelo Ingress (com tags corretas)
- Cognito User Pool ativo
- Lambda deployada

**Aplicar:**
```bash
cd infra/api-gateway
terraform init
terraform plan
terraform apply
```

**Anotar URL do API Gateway:**
```bash
terraform output api_gateway_url
# Exemplo: https://abc123.execute-api.us-east-1.amazonaws.com/v1
```

---

#### 4.4 Testes de Autenticação (1-2 horas)
```bash
API_URL="$(cd infra/api-gateway && terraform output -raw api_gateway_url)"

# 1. Identificar (sem auth)
curl -X POST $API_URL/auth/identificar \
  -H "Content-Type: application/json" \
  -d '{"cpf": "12345678900"}'
# Retorna: accessToken

# 2. Usar token para criar pedido (com auth)
TOKEN="eyJraWQ..."  # Token retornado acima

curl -X POST $API_URL/autoatendimento/pedidos \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"cpfCliente": "12345678900", "itens": [{"produtoId": 1, "quantidade": 1}]}'
```

---

#### 4.5 Validação E2E Completa (1-2 horas)
**Executar script E2E adaptado para AWS:**

```bash
cd test_scripts
cp test-e2e.sh test-e2e-aws.sh

# Editar test-e2e-aws.sh
# Substituir:
# PEDIDOS_URL=$(minikube service pedidos-nodeport --url)
# Por:
# PEDIDOS_URL="$API_GATEWAY_URL/autoatendimento"
# COZINHA_URL="$API_GATEWAY_URL/autoatendimento"

./test-e2e-aws.sh
```

**Fluxo esperado:**
1. ✅ Identificar cliente → Token JWT
2. ✅ Criar pedido (com token) → CRIADO
3. ✅ Pagamento automático → REALIZADO
4. ✅ Fila da cozinha → AGUARDANDO
5. ✅ Iniciar preparo → EM_PREPARO
6. ✅ Marcar pronto → PRONTO
7. ✅ Retirar pedido → FINALIZADO

---

## 📊 CHECKLIST COMPLETO - FASE A

### Dia 1: Preparação
- [ ] Expandir ECR (adicionar 3 repos)
- [ ] Criar 3 Dockerfiles
- [ ] Build e push de 5 imagens Docker

### Dia 2: EKS
- [ ] Aplicar Terraform EKS
- [ ] Configurar kubectl
- [ ] Deploy StatefulSets (bancos)
- [ ] Deploy microserviços
- [ ] Validar pods rodando

### Dia 3: Ingress
- [ ] Aplicar AWS Load Balancer Controller
- [ ] Criar Ingress resource
- [ ] Aguardar ALB provisionado
- [ ] Testar endpoints via ALB

### Dia 4: Cognito
- [ ] Aplicar Terraform Cognito
- [ ] Aplicar Lambda
- [ ] Aplicar API Gateway
- [ ] Testar autenticação
- [ ] Executar testes E2E completos

---

## 🎯 CRITÉRIOS DE SUCESSO

### Infraestrutura
- [x] Backend S3 + DynamoDB ativo
- [ ] 5 repositórios ECR provisionados
- [ ] EKS cluster rodando (2+ nodes)
- [ ] Todos os StatefulSets rodando (5 pods)
- [ ] Todos os microserviços rodando (8+ pods)
- [ ] ALB provisionado e respondendo
- [ ] Cognito User Pool ativo

### Funcionalidade
- [ ] Health checks passando (100%)
- [ ] Endpoints acessíveis via ALB
- [ ] Autenticação Cognito funcionando
- [ ] Integração RabbitMQ funcionando
- [ ] Integração Feign Client funcionando
- [ ] Testes E2E passando na AWS

### Documentação
- [ ] URLs do ALB documentadas
- [ ] Credenciais Cognito documentadas
- [ ] Diagrama de arquitetura AWS atualizado

---

## ⚠️ RISCOS E MITIGAÇÕES

### Risco 1: ALB não provisiona
**Sintoma:** Ingress fica sem ADDRESS
**Causa:** Subnet tags incorretas
**Mitigação:** Verificar tags `kubernetes.io/role/elb=1` nas subnets públicas

### Risco 2: Pods não iniciam
**Sintoma:** CrashLoopBackOff ou ImagePullBackOff
**Causa:** Imagens não encontradas no ECR
**Mitigação:** Verificar URLs ECR nos deployments

### Risco 3: StatefulSets sem storage
**Sintoma:** Pods pending
**Causa:** PVCs não criados (falta StorageClass)
**Mitigação:** Usar StorageClass `gp2` (default no EKS)

### Risco 4: Cognito não autentica
**Sintoma:** Token inválido (401)
**Causa:** Configuração incorreta do Authorizer
**Mitigação:** Verificar outputs do Terraform (user_pool_id, client_id)

---

## 📝 PRÓXIMOS PASSOS (PÓS FASE A)

Após conclusão da Fase A, seguir para:

**FASE B: Qualidade e CI/CD (4-5 dias)**
1. Implementar BDD com Cucumber
2. Configurar SonarQube
3. Atualizar CI/CD para AWS
4. Remover monolito legado

**FASE C: Entrega (1 dia)**
5. Preparar vídeo de demonstração

---

## 🔗 LINKS ÚTEIS

- [README Principal](../README.md)
- [BACKLOG Atualizado](../BACKLOG.md)
- [Terraform Backend](../infra/backend/)
- [Terraform EKS](../infra/kubernetes/)
- [Terraform Cognito](../infra/auth/)
- [Manifestos K8s](../k8s/)

---

**Responsável:** Anderson
**Status:** Pronto para Execução
**Última Revisão:** 2025-10-24
