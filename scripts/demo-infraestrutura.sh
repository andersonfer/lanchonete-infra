#!/bin/bash

# Script de demonstração da infraestrutura AWS
# Focado em mostrar cada componente funcionando

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Função para títulos principais
print_header() {
    echo -e "\n${WHITE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}  $1${NC}"
    echo -e "${WHITE}════════════════════════════════════════════════════════════${NC}\n"
}

# Função para subtítulos
print_section() {
    echo -e "\n${CYAN}▶ $1${NC}\n"
}

# Função para aguardar input do usuário
wait_for_user() {
    if [ "$1" != "--no-pause" ]; then
        echo -e "\n${YELLOW}[Pressione ENTER para continuar...]${NC}"
        read -r
    fi
}

# Função para executar comando com highlight
execute_command() {
    echo -e "${BLUE}💻 Executando: $1${NC}"
    eval "$1"
    echo ""
}

echo -e "${PURPLE}"
cat << 'EOF'
╔═══════════════════════════════════════════════════════════╗
║           DEMONSTRAÇÃO DA INFRAESTRUTURA AWS              ║
║               Sistema de Lanchonete                       ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

wait_for_user "$1"

# ============================================================================
print_header "1. BACKEND TERRAFORM - S3 + DynamoDB"
# ============================================================================

print_section "Verificando o bucket S3 para Terraform state"
execute_command "aws s3 ls s3://lanchonete-terraform-state-poc/"

print_section "Verificando a tabela DynamoDB para locks"
execute_command "aws dynamodb describe-table --table-name lanchonete-terraform-locks --query 'Table.{Name:TableName,Status:TableStatus,Items:ItemCount}' --output table"

wait_for_user "$1"

# ============================================================================
print_header "2. REPOSITÓRIOS ECR - Imagens Docker"
# ============================================================================

print_section "Listando repositórios ECR criados"
execute_command "aws ecr describe-repositories --query 'repositories[].{Nome:repositoryName,URI:repositoryUri}' --output table"

print_section "Verificando imagens no repositório autoatendimento"
execute_command "aws ecr describe-images --repository-name lanchonete-autoatendimento --query 'imageDetails[].{Tags:imageTags,Size:imageSizeInBytes,Pushed:imagePushedAt}' --output table"

print_section "Verificando imagens no repositório pagamento"
execute_command "aws ecr describe-images --repository-name lanchonete-pagamento --query 'imageDetails[].{Tags:imageTags,Size:imageSizeInBytes,Pushed:imagePushedAt}' --output table"

wait_for_user "$1"

# ============================================================================
print_header "3. RDS MySQL - Banco de Dados"
# ============================================================================

print_section "Verificando instância RDS MySQL"
execute_command "aws rds describe-db-instances --db-instance-identifier lanchonete-mysql --query 'DBInstances[0].{ID:DBInstanceIdentifier,Status:DBInstanceStatus,Engine:Engine,Class:DBInstanceClass,Storage:AllocatedStorage,Endpoint:Endpoint.Address}' --output table"

wait_for_user "$1"

# ============================================================================
print_header "4. CLUSTER EKS - Kubernetes"
# ============================================================================

print_section "Verificando cluster EKS"
execute_command "aws eks describe-cluster --name lanchonete-cluster --query 'cluster.{Nome:name,Status:status,Version:version,Endpoint:endpoint}' --output table"

print_section "Verificando nodes do cluster"
execute_command "kubectl get nodes -o wide"

print_section "Verificando node groups"
execute_command "aws eks describe-nodegroup --cluster-name lanchonete-cluster --nodegroup-name lanchonete-nodes --query 'nodegroup.{Nome:nodegroupName,Status:status,InstanceTypes:instanceTypes,DesiredSize:scalingConfig.desiredSize}' --output table"

wait_for_user "$1"

# ============================================================================
print_header "5. APLICAÇÕES KUBERNETES - Pods e Services"
# ============================================================================

print_section "Verificando deployments"
execute_command "kubectl get deployments -o wide"

print_section "Verificando pods"
execute_command "kubectl get pods -o wide"

print_section "Verificando services"
execute_command "kubectl get services -o wide"

wait_for_user "$1"

# ============================================================================
print_header "6. APPLICATION LOAD BALANCERS (ALBs)"
# ============================================================================

print_section "Verificando Ingresses (ALBs) criados pelo AWS Load Balancer Controller"
execute_command "kubectl get ingress -o wide"

print_section "Listando ALBs via AWS CLI"
execute_command "aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, \`lanchonete\`)].{Nome:LoadBalancerName,DNS:DNSName,Estado:State.Code,Tipo:Type}' --output table"


wait_for_user "$1"

# ============================================================================
print_header "7. COGNITO USER POOL - Autenticação"
# ============================================================================

print_section "Verificando Cognito User Pool"
execute_command "aws cognito-idp list-user-pools --max-results 10 --query 'UserPools[?contains(Name, \`lanchonete\`)].{Nome:Name,Id:Id}' --output table"

# Obter detalhes do User Pool
USER_POOL_ID=$(cd ../infra/auth && terraform output -raw user_pool_id 2>/dev/null || echo "us-east-1_JQFyBEeak")

print_section "Detalhes do User Pool"
execute_command "aws cognito-idp describe-user-pool --user-pool-id $USER_POOL_ID --query 'UserPool.{Nome:Name,Id:Id,MfaConfiguration:MfaConfiguration}' --output table"

wait_for_user "$1"

# ============================================================================
print_header "8. LAMBDA - Função de Autenticação"
# ============================================================================

print_section "Verificando função Lambda"
execute_command "aws lambda get-function --function-name lanchonete-auth-lambda --query 'Configuration.{Nome:FunctionName,Runtime:Runtime,Status:State,Memory:MemorySize,Timeout:Timeout}' --output table"

print_section "Verificando logs recentes da Lambda"
echo -e "${BLUE}💻 Últimas execuções da Lambda...${NC}"
aws logs describe-log-streams --log-group-name "/aws/lambda/lanchonete-auth-lambda" --order-by LastEventTime --descending --max-items 3 --query 'logStreams[].{Stream:logStreamName,LastEvent:lastEventTimestamp}' --output table

wait_for_user "$1"

# ============================================================================
print_header "9. API GATEWAY - Proteção dos Serviços"
# ============================================================================

print_section "Verificando API Gateway"
API_ID=$(cd ../infra/api-gateway && terraform output -raw api_gateway_id 2>/dev/null || echo "o8wsi7rqp8")
API_URL=$(cd ../infra/api-gateway && terraform output -raw api_gateway_endpoint 2>/dev/null || echo "https://o8wsi7rqp8.execute-api.us-east-1.amazonaws.com/v1")

execute_command "aws apigateway get-rest-api --rest-api-id $API_ID --query '{Nome:name,Id:id,Criado:createdDate}' --output table"

wait_for_user "$1"

echo -e "\n${GREEN}✅ Demonstração completa da infraestrutura finalizada!${NC}\n"