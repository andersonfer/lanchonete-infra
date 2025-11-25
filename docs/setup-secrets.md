# 🚀 Setup Completo - Tech Challenge Fase 2

Guia passo a passo para novos desenvolvedores configurarem o ambiente do projeto lanchonete.

## 📋 Pré-requisitos

Antes de começar, certifique-se de ter instalado:

- ✅ **Docker** (para build das imagens)
- ✅ **Minikube** (ambiente Kubernetes local)
- ✅ **kubectl** (cliente Kubernetes)
- ✅ **Git** (versionamento)

### Verificar pré-requisitos
```bash
# Verificar se tudo está instalado
docker --version
minikube version
kubectl version --client
git --version
```

## 🔧 Setup Inicial

### 1. Iniciar Minikube
```bash
# Iniciar cluster Kubernetes local
minikube start

# Habilitar metrics (para HPA)
minikube addons enable metrics-server

# Verificar status
minikube status
```

### 2. Clonar o Repositório
```bash
# Clonar projeto
git clone https://github.com/[seu-usuario]/lanchonete-app.git
cd lanchonete-app

# Verificar branch atual
git branch
```

## 🔐 Configuração de Secrets

**⚠️ IMPORTANTE:** Este projeto não utiliza senhas hardcoded. Você precisa definir suas próprias senhas.

### 3. Obter Senhas da Equipe

**Entre em contato com a equipe** para obter as senhas padrão utilizadas no projeto:
- Slack, Teams, ou canal de comunicação da equipe
- **NUNCA** compartilhe senhas em locais públicos

### 4. Configurar Variáveis de Ambiente

```bash
# Opção A: Usar arquivo .env (recomendado)
cp .env.example .env
nano .env  # Editar com as senhas reais

# Carregar variáveis
export $(cat .env | grep -v '^#' | xargs)

# Opção B: Definir manualmente
export MYSQL_ROOT_PASSWORD="senha_obtida_da_equipe"
export MYSQL_USER_PASSWORD="senha_obtida_da_equipe"
```

### 5. Criar Secrets no Kubernetes
```bash
# Executar script de criação de secrets
bash k8s/secrets/create_secrets.sh

# Verificar se foi criado
kubectl get secret mysql-secret
```

## 🏗️ Build e Deploy

### 6. Build das Aplicações
```bash
# Build de todas as imagens
docker-compose build

# Carregar imagens no Minikube
minikube image load lanchonete-app-autoatendimento:latest
minikube image load lanchonete-app-pagamento:latest

# Verificar imagens carregadas
minikube image list | grep lanchonete
```

### 7. Deploy Completo
```bash
# Deploy automatizado (recomendado)
chmod +x aplicar_manifests.sh
./aplicar_manifests.sh

# OU deploy manual por etapas:
# kubectl apply -f k8s/configmaps/
# kubectl apply -f k8s/storage/
# kubectl apply -f k8s/deployments/mysql-statefulset.yaml
# kubectl apply -f k8s/services/mysql-services.yaml
# kubectl apply -f k8s/deployments/
# kubectl apply -f k8s/services/app-services.yaml
# kubectl apply -f k8s/hpa/
```

## ✅ Verificação do Ambiente

### 8. Validar Deploy
```bash
# Script de validação completa
chmod +x validar_deploy_k8s.sh
./validar_deploy_k8s.sh

# Verificação manual
kubectl get pods,services,hpa
```

### 9. Testar Aplicações
```bash
# Obter IP do Minikube
minikube ip

# Acessar aplicações
echo "Autoatendimento: http://$(minikube ip):30080/swagger-ui.html"
echo "Pagamento: http://$(minikube ip):30081/swagger-ui.html"
```

### 10. Teste de Conectividade
```bash
# Testar MySQL
kubectl exec -it mysql-statefulset-0 -- mysql -u root -p$MYSQL_ROOT_PASSWORD -e "SELECT 'MySQL OK';"

# Testar APIs
curl "http://$(minikube ip):30080/produtos/categoria/LANCHE"
curl "http://$(minikube ip):30081/actuator/health"
```

## 🐛 Troubleshooting Comum

### Problema: Pods não sobem
```bash
# Verificar status detalhado
kubectl describe pods

# Verificar logs
kubectl logs -l app=mysql
kubectl logs -l app=autoatendimento
```

### Problema: Secrets não funcionam
```bash
# Verificar se secret existe
kubectl get secrets

# Recriar secrets
kubectl delete secret mysql-secret
bash k8s/secrets/create_secrets.sh
```

### Problema: Imagens não encontradas
```bash
# Verificar imagens no Minikube
minikube image list | grep lanchonete

# Rebuild e reload
docker-compose build
minikube image load lanchonete-app-autoatendimento:latest
minikube image load lanchonete-app-pagamento:latest
```

### Problema: MySQL não conecta
```bash
# Verificar se MySQL está rodando
kubectl get pods -l app=mysql

# Verificar logs do MySQL
kubectl logs mysql-statefulset-0

# Testar conexão direta
kubectl exec -it mysql-statefulset-0 -- mysql -u root -p
```

## 🔄 Workflow de Desenvolvimento

### Desenvolvimento Local
```bash
# 1. Fazer alterações no código
# 2. Rebuild da imagem alterada
docker-compose build autoatendimento  # ou pagamento

# 3. Recarregar no Minikube
minikube image load lanchonete-app-autoatendimento:latest

# 4. Restart do deployment
kubectl rollout restart deployment/autoatendimento-deployment
```

### Limpeza do Ambiente
```bash
# Limpar tudo (quando necessário)
chmod +x limpar_k8s.sh
./limpar_k8s.sh

# Rebuild completo
./aplicar_manifests.sh
```

## 📚 Documentação Adicional

- **Secrets:** `k8s/secrets/README.md` - Gestão detalhada de secrets
- **APIs:** Swagger UI nas URLs das aplicações
- **Kubernetes:** Manifests em `k8s/` com comentários

## 🆘 Contatos da Equipe

Se tiver problemas:
1. **Verifique** este guia e a documentação
2. **Execute** scripts de validação
3. **Consulte** logs do Kubernetes
4. **Entre em contato** com a equipe

---

**🎯 Sucesso:** Se conseguir acessar o Swagger UI e criar um pedido, seu ambiente está funcionando perfeitamente!
