# Lanchonete Infra

Infraestrutura como Código (IaC) para o sistema de lanchonete, utilizando Terraform para provisionar recursos na AWS e manifests Kubernetes compartilhados.

## Estrutura

```
lanchonete-infra/
├── terraform/
│   ├── backend/        # S3 + DynamoDB para Terraform state
│   ├── ecr/            # Container Registry (4 repositórios)
│   ├── kubernetes/     # EKS Cluster + Node Group
│   ├── database/       # RDS MySQL (3 instâncias)
│   ├── auth/           # Cognito User Pool
│   ├── lambda/         # Lambda de autenticação
│   └── api-gateway/    # API Gateway + Authorizer
├── k8s/
│   ├── shared-rabbitmq-statefulset.yaml   # RabbitMQ compartilhado
│   ├── pagamento-mongodb-statefulset.yaml # MongoDB para Pagamento
│   └── create-secrets.sh                   # Script para criar secrets
├── scripts/            # Scripts de deploy e manutenção
└── docs/               # Documentação adicional
```

## Pré-requisitos

- AWS CLI configurado
- Terraform >= 1.0
- kubectl configurado

## Provisionar Infraestrutura

### 1. Backend (executar primeiro)

```bash
cd terraform/backend
terraform init
terraform apply
```

### 2. Demais módulos (em ordem)

```bash
# ECR
cd ../ecr && terraform init && terraform apply

# EKS
cd ../kubernetes && terraform init && terraform apply

# RDS
cd ../database && terraform init && terraform apply

# Cognito
cd ../auth && terraform init && terraform apply

# Lambda
cd ../lambda && terraform init && terraform apply

# API Gateway
cd ../api-gateway && terraform init && terraform apply
```

### 3. Configurar kubectl

```bash
aws eks update-kubeconfig --name lanchonete-cluster --region us-east-1
```

### 4. Deploy dos recursos compartilhados

```bash
# Criar secrets
./k8s/create-secrets.sh

# RabbitMQ
kubectl apply -f k8s/shared-rabbitmq-statefulset.yaml

# MongoDB (para serviço de pagamento)
kubectl apply -f k8s/pagamento-mongodb-statefulset.yaml
```

## Recursos Provisionados

| Módulo | Recursos |
|--------|----------|
| `backend/` | S3 Bucket + DynamoDB (Terraform state) |
| `ecr/` | 4 repositórios ECR (clientes, pedidos, cozinha, pagamento) |
| `kubernetes/` | EKS Cluster + Node Group (t3.medium) |
| `database/` | 3 instâncias RDS MySQL (db.t3.micro) |
| `auth/` | Cognito User Pool |
| `lambda/` | Lambda Java 17 (autenticação) |
| `api-gateway/` | REST API + Cognito Authorizer |

## Repositórios Relacionados

- [lanchonete-clientes](https://github.com/andersonfer/lanchonete-clientes)
- [lanchonete-pedidos](https://github.com/andersonfer/lanchonete-pedidos)
- [lanchonete-cozinha](https://github.com/andersonfer/lanchonete-cozinha)
- [lanchonete-pagamento](https://github.com/andersonfer/lanchonete-pagamento)
