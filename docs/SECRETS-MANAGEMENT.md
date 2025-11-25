# Gestão de Secrets no Kubernetes

## Visão Geral

Este projeto usa **Kubernetes Secrets** para armazenar credenciais sensíveis (senhas de banco de dados, etc.).

**Princípio:** Secrets NUNCA são commitados no Git em texto puro.

---

## Abordagem Adotada

### Script de Criação Dinâmica

Os secrets são criados via script `scripts/create-secrets.sh` que:
1. Lê variáveis de ambiente
2. Usa valores padrão se não configuradas (apenas dev local)
3. Cria secrets no cluster Kubernetes atual

**Vantagens:**
- ✅ Nada de sensível commitado no Git
- ✅ Flexível para múltiplos ambientes
- ✅ Fácil rotação de credenciais

---

## Configuração por Ambiente

### 1. Desenvolvimento Local (Minikube)

**Opção A: Usar valores padrão (mais fácil)**

```bash
# Simplesmente execute o script
./scripts/create-secrets.sh
```

Usa senhas padrão: `root123`, `clientes123`, etc.

**Opção B: Configurar via .env**

```bash
# 1. Copiar template
cp .env.example .env

# 2. Editar .env com suas senhas
nano .env

# 3. Executar script (carrega .env automaticamente)
./scripts/create-secrets.sh
```

---

### 2. AWS EKS (Demonstração)

**Via variáveis de ambiente:**

```bash
# Exportar variáveis
export MYSQL_ROOT_PASSWORD="senha-forte-aqui"
export MYSQL_CLIENTES_PASSWORD="outra-senha-forte"
export MYSQL_PEDIDOS_PASSWORD="mais-uma-senha"
export MYSQL_COZINHA_PASSWORD="senha-cozinha"
export MONGO_PASSWORD="senha-mongo"
export RABBITMQ_PASSWORD="senha-rabbit"

# Configurar kubectl para EKS
aws eks update-kubeconfig --name lanchonete-cluster --region us-east-1

# Executar script
./scripts/create-secrets.sh
```

---

### 3. GitHub Actions (CI/CD)

**Configurar GitHub Secrets:**

1. Ir em: `Settings > Secrets and variables > Actions`
2. Adicionar secrets:
   - `MYSQL_ROOT_PASSWORD`
   - `MYSQL_CLIENTES_PASSWORD`
   - `MYSQL_PEDIDOS_PASSWORD`
   - `MYSQL_COZINHA_PASSWORD`
   - `MONGO_PASSWORD`
   - `RABBITMQ_PASSWORD`

**No workflow:**

```yaml
# .github/workflows/deploy.yml
- name: Criar Secrets no Kubernetes
  env:
    MYSQL_ROOT_PASSWORD: ${{ secrets.MYSQL_ROOT_PASSWORD }}
    MYSQL_CLIENTES_PASSWORD: ${{ secrets.MYSQL_CLIENTES_PASSWORD }}
    MYSQL_PEDIDOS_PASSWORD: ${{ secrets.MYSQL_PEDIDOS_PASSWORD }}
    MYSQL_COZINHA_PASSWORD: ${{ secrets.MYSQL_COZINHA_PASSWORD }}
    MONGO_PASSWORD: ${{ secrets.MONGO_PASSWORD }}
    RABBITMQ_PASSWORD: ${{ secrets.RABBITMQ_PASSWORD }}
  run: ./scripts/create-secrets.sh
```

---

## Secrets Criados

O script cria 5 secrets:

### 1. `mysql-clientes-secret`
```yaml
MYSQL_ROOT_PASSWORD: <senha>
MYSQL_DATABASE: clientes_db
MYSQL_USER: clientes_user
MYSQL_PASSWORD: <senha>
```

### 2. `mysql-pedidos-secret`
```yaml
MYSQL_ROOT_PASSWORD: <senha>
MYSQL_DATABASE: pedidos_db
MYSQL_USER: pedidos_user
MYSQL_PASSWORD: <senha>
```

### 3. `mysql-cozinha-secret`
```yaml
MYSQL_ROOT_PASSWORD: <senha>
MYSQL_DATABASE: cozinha_db
MYSQL_USER: cozinha_user
MYSQL_PASSWORD: <senha>
```

### 4. `mongodb-secret`
```yaml
MONGO_INITDB_ROOT_USERNAME: admin
MONGO_INITDB_ROOT_PASSWORD: <senha>
MONGO_INITDB_DATABASE: pagamentos
```

### 5. `rabbitmq-secret`
```yaml
RABBITMQ_DEFAULT_USER: admin
RABBITMQ_DEFAULT_PASS: <senha>
```

---

## Como os Secrets são Usados

### StatefulSets (Databases)

```yaml
# k8s/databases/mysql-clientes.yaml
spec:
  template:
    spec:
      containers:
      - name: mysql
        envFrom:
        - secretRef:
            name: mysql-clientes-secret
```

### Deployments (Microserviços)

```yaml
# k8s/services/clientes-deployment.yaml
spec:
  template:
    spec:
      containers:
      - name: clientes
        env:
        - name: SPRING_DATASOURCE_URL
          value: "jdbc:mysql://mysql-clientes-service:3306/clientes_db"
        - name: SPRING_DATASOURCE_USERNAME
          valueFrom:
            secretKeyRef:
              name: mysql-clientes-secret
              key: MYSQL_USER
        - name: SPRING_DATASOURCE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-clientes-secret
              key: MYSQL_PASSWORD
```

---

## Comandos Úteis

### Listar secrets
```bash
kubectl get secrets
```

### Ver detalhes (não mostra valores)
```bash
kubectl describe secret mysql-clientes-secret
```

### Ver valores (base64 encoded)
```bash
kubectl get secret mysql-clientes-secret -o yaml
```

### Decodificar valor específico
```bash
kubectl get secret mysql-clientes-secret -o jsonpath='{.data.MYSQL_PASSWORD}' | base64 --decode
```

### Deletar secret
```bash
kubectl delete secret mysql-clientes-secret
```

### Recriar todos os secrets
```bash
./scripts/create-secrets.sh
```

---

## Rotação de Senhas

### Passo 1: Atualizar variáveis de ambiente
```bash
export MYSQL_CLIENTES_PASSWORD="nova-senha"
```

### Passo 2: Recriar secret
```bash
kubectl delete secret mysql-clientes-secret
./scripts/create-secrets.sh
```

### Passo 3: Reiniciar pods para usar nova senha
```bash
kubectl rollout restart statefulset/mysql-clientes
kubectl rollout restart deployment/clientes
```

---

## Segurança

### ✅ Boas Práticas Implementadas

- Secrets não commitados no Git (`.gitignore`)
- Valores padrão APENAS para dev local
- Script lê de variáveis de ambiente
- GitHub Actions usa GitHub Secrets

### ⚠️ Limitações (Ambiente Acadêmico)

- Secrets armazenados em etcd não-encriptado (padrão K8s)
- Sem rotação automática
- Sem integração com AWS Secrets Manager

### 🔒 Para Produção Real (Futuro)

Considerar:
- **Sealed Secrets:** Encripta secrets para commit seguro no Git
- **External Secrets Operator:** Integra com AWS Secrets Manager
- **Vault:** HashiCorp Vault para gestão centralizada
- **RBAC:** Limitar quem pode acessar secrets

---

## Troubleshooting

### Erro: "secret already exists"
```bash
# Deletar e recriar
kubectl delete secret mysql-clientes-secret
./scripts/create-secrets.sh
```

### Pod não inicia (erro de autenticação MySQL)
```bash
# Verificar se secret existe
kubectl get secret mysql-clientes-secret

# Ver valores
kubectl get secret mysql-clientes-secret -o yaml

# Recriar secret e reiniciar pod
./scripts/create-secrets.sh
kubectl delete pod mysql-clientes-0
```

### Esqueci a senha
```bash
# Ver senha atual
kubectl get secret mysql-clientes-secret -o jsonpath='{.data.MYSQL_PASSWORD}' | base64 --decode
echo
```

---

## Referências

- [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [External Secrets Operator](https://external-secrets.io/)
