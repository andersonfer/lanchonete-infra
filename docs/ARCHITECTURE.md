# Arquitetura de Microserviços - Sistema Lanchonete

## Decisões Arquiteturais (ADRs)

### ADR-001: Migração de Monólito para Microserviços

**Status:** Aceito

**Contexto:**
- Sistema atual: aplicação monolítica (`autoatendimento`) com todas as funcionalidades
- Necessidade de escalabilidade independente de componentes
- Facilitar desenvolvimento e deploy de funcionalidades isoladas
- Ambiente AWS Academy (infraestrutura efêmera)

**Decisão:**
Migrar para arquitetura de microserviços com 4 serviços independentes:
1. **Clientes** - Gestão de identificação e cadastro
2. **Pedidos** - Orquestração de pedidos e produtos
3. **Cozinha** - Fila de produção
4. **Pagamento** - Processamento de pagamentos (mock)

**Consequências:**
- ✅ Escalabilidade independente por serviço
- ✅ Deploy isolado sem impacto em outros serviços
- ✅ Tecnologias específicas por contexto (MongoDB para pagamento)
- ❌ Complexidade operacional aumentada
- ❌ Necessidade de mensageria assíncrona
- ❌ Gestão de múltiplos bancos de dados

---

### ADR-002: Database Per Service Pattern

**Status:** Aceito

**Contexto:**
- Monólito atual usa um único banco MySQL compartilhado
- Microserviços devem ter autonomia completa
- Pagamento requer persistência de dados não-relacionais

**Decisão:**
Cada microserviço terá seu próprio banco de dados isolado:
- **Clientes:** MySQL (StatefulSet)
- **Pedidos:** MySQL (StatefulSet)
- **Cozinha:** MySQL (StatefulSet)
- **Pagamento:** MongoDB (StatefulSet)

**Consequências:**
- ✅ Autonomia completa de cada serviço
- ✅ Schema evolution independente
- ✅ Tecnologia adequada ao contexto (MongoDB para dados não-estruturados)
- ❌ Não há joins entre bancos (necessita REST calls)
- ❌ Consistência eventual em alguns cenários
- ❌ Maior consumo de recursos (4 databases)

---

### ADR-003: Comunicação Síncrona via REST + Assíncrona via RabbitMQ

**Status:** Aceito

**Contexto:**
- Alguns dados precisam ser consultados em tempo real (ex: validar cliente)
- Fluxo de pedidos requer orquestração entre serviços
- Desacoplamento temporal é desejável para resiliência

**Decisão:**

**Comunicação Síncrona (REST):**
- Pedidos → Clientes: `GET /clientes/{cpf}` (validação)
- Cozinha → Pedidos: `GET /pedidos/{id}` (detalhes do pedido)

**Comunicação Assíncrona (RabbitMQ):**
- `PedidoCriado`: Pedidos → Pagamento
- `PagamentoAprovado`: Pagamento → Pedidos + Cozinha
- `PagamentoRejeitado`: Pagamento → Pedidos
- `PedidoPronto`: Cozinha → Pedidos
- `PedidoRetirado`: Pedidos → Cozinha

**Consequências:**
- ✅ Validações em tempo real quando necessário
- ✅ Desacoplamento temporal para fluxos longos
- ✅ Resiliência (serviços podem processar eventos depois)
- ❌ Curva de aprendizado RabbitMQ
- ❌ Debugging mais complexo (rastreamento distribuído)
- ❌ Necessidade de idempotência nos consumers

---

### ADR-004: Kubernetes como Orquestrador (Minikube Local + EKS Produção)

**Status:** Aceito

**Contexto:**
- AWS Academy destrói infraestrutura ao final da sessão
- Necessidade de desenvolvimento local sem custos
- Demonstração final requer ambiente cloud profissional

**Decisão:**
- **Desenvolvimento:** Minikube (NodePort para acesso)
- **Produção/Demo:** Amazon EKS (Application Load Balancer)
- Mesmos manifests YAML em ambos ambientes (máxima portabilidade)

**Consequências:**
- ✅ Desenvolvimento local rápido e sem custos
- ✅ Paridade dev/prod (mesmos manifests)
- ✅ Infraestrutura como código (reproduzível)
- ❌ Minikube requer recursos locais (RAM/CPU)
- ❌ EKS provisioning demora ~15min

---

### ADR-005: Autenticação Simplificada sem JWT

**Status:** Aceito

**Contexto:**
- Monólito atual usava Lambda + Cognito + API Gateway
- Complexidade desnecessária para escopo do projeto
- Foco em arquitetura de microserviços, não em segurança avançada

**Decisão:**
Autenticação simplificada baseada em CPF:
1. Cliente anônimo: `cpfCliente = null` (permitido)
2. Cliente identificado: REST call `GET /clientes/{cpf}` valida existência
3. Novo cliente: se CPF não existe, cria automaticamente

**Sem JWT entre microserviços** (comunicação interna confiável).

**Consequências:**
- ✅ Simplicidade operacional (menos componentes)
- ✅ Foco em arquitetura de microserviços
- ✅ Menos recursos AWS necessários
- ❌ Não adequado para produção real (sem autenticação forte)
- ❌ Sem autorização granular

---

### ADR-006: StatefulSets para Databases e RabbitMQ

**Status:** Aceito

**Contexto:**
- Ambiente AWS Academy efêmero (RDS seria destruído)
- Necessidade de bancos locais no Minikube
- Paridade entre ambientes dev/prod

**Decisão:**
Usar **Kubernetes StatefulSets** para todos componentes stateful:
- 3x MySQL (Clientes, Pedidos, Cozinha)
- 1x MongoDB (Pagamento)
- 1x RabbitMQ

Com **PersistentVolumeClaims (PVC)** de 5Gi cada.

**Consequências:**
- ✅ Funciona igual em Minikube e EKS
- ✅ Sem dependência de serviços gerenciados AWS
- ✅ Dados persistem entre restarts de pods
- ❌ Sem backups automáticos (RDS oferece)
- ❌ Performance inferior a serviços gerenciados
- ❌ Responsabilidade de manutenção do DBA

---

### ADR-007: Clean Architecture por Microserviço

**Status:** Aceito

**Contexto:**
- Monólito atual usa Clean Architecture com sucesso
- Padrão familiar ao time
- Separação clara de responsabilidades

**Decisão:**
Manter estrutura Clean Architecture em cada microserviço:

```
services/{servico}/
├── dominio/          # Entidades, Value Objects, regras de negócio
├── aplicacao/        # Casos de uso, interfaces (gateways)
├── infra/            # Implementações (JDBC, REST, RabbitMQ)
└── apresentacao/     # Controllers, DTOs
```

**Consequências:**
- ✅ Padrão consistente entre serviços
- ✅ Testabilidade (camadas isoladas)
- ✅ Reaproveitamento de código do monólito
- ❌ Mais arquivos/pacotes (pode parecer over-engineering para serviços simples)

---

### ADR-008: Snapshot de Preços em ItemPedido

**Status:** Aceito (já existente no monólito)

**Contexto:**
- Preço de produtos pode mudar ao longo do tempo
- Pedidos antigos devem manter preço original

**Decisão:**
Ao criar pedido, copiar `produto.preco` para `item_pedido.valor_unitario` (snapshot).

**Consequências:**
- ✅ Auditoria correta (pedidos não mudam retroativamente)
- ✅ Relatórios financeiros precisos
- ❌ Duplicação de dados (trade-off aceitável)

---

### ADR-009: Estados Unificados de Pedido

**Status:** Aceito

**Contexto:**
- Monólito tinha `StatusPedido` e `StatusPagamento` separados
- Microserviços precisam de estados claros para orquestração

**Decisão:**
Unificar em um único enum `StatusPedido`:

```
CRIADO → REALIZADO/CANCELADO → EM_PREPARACAO → PRONTO → FINALIZADO
```

**Mapeamento:**
- `CRIADO`: Pedido criado, aguardando pagamento
- `REALIZADO`: Pagamento aprovado (evento `PagamentoAprovado`)
- `CANCELADO`: Pagamento rejeitado (evento `PagamentoRejeitado`)
- `EM_PREPARACAO`: Cozinha iniciou preparo
- `PRONTO`: Cozinha finalizou
- `FINALIZADO`: Cliente retirou pedido

**Consequências:**
- ✅ Estado único e claro
- ✅ Facilita rastreamento
- ✅ Alinhamento com eventos de mensageria
- ❌ Breaking change do monólito (requer migração)

---

### ADR-010: CI/CD com GitHub Actions

**Status:** Aceito

**Contexto:**
- Pipeline atual funciona bem
- Integração nativa com ECR e EKS
- Gratuito para projetos acadêmicos

**Decisão:**
Manter GitHub Actions com ajustes:
1. Build Maven de 4 serviços
2. Testes unitários obrigatórios
3. Build Docker de 4 imagens
4. Push para ECR
5. Deploy via `kubectl apply`
6. Smoke tests

**Consequências:**
- ✅ Gratuito (minutos inclusos GitHub)
- ✅ Familiar ao time
- ✅ Logs centralizados no GitHub
- ❌ Menos features que Jenkins

---

## Diagramas de Arquitetura

### Visão Geral

```
┌─────────────────────────────────────────────────────────────┐
│                      CLIENTE (Browser/App)                   │
└────────────────────────────┬────────────────────────────────┘
                             │ HTTPS
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                   AWS ALB (EKS) / NodePort (Minikube)        │
│                                                              │
│  /clientes/*   → clientes-service:8083                       │
│  /pedidos/*    → pedidos-service:8080                        │
│  /cozinha/*    → cozinha-service:8082                        │
│  /pagamentos/* → pagamento-service:8081                      │
└────────────────────────────┬────────────────────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   CLIENTES   │◄────┤   PEDIDOS    │────►│   COZINHA    │
│   :8083      │ REST│   :8080      │ REST│   :8082      │
│              │     │              │     │              │
│  MySQL       │     │  MySQL       │     │  MySQL       │
└──────────────┘     └──────┬───────┘     └──────────────┘
                            │                     ▲
                            │  RabbitMQ           │
                            │  (async)            │
                            ▼                     │
                     ┌──────────────┐             │
                     │  PAGAMENTO   │─────────────┘
                     │   :8081      │
                     │              │
                     │  MongoDB     │
                     └──────────────┘
```

### Fluxo de Eventos RabbitMQ

```
[Pedidos] ──PedidoCriado──────────────────────► [Pagamento]
                                                      │
    ┌────────────────────────────────────────────────┤
    │                                                │
    │ PagamentoAprovado                  PagamentoRejeitado
    │                                                │
    ▼                                                ▼
[Pedidos] ◄──────────────────────────────────── [Pedidos]
    │                                          (status=CANCELADO)
    │ status=REALIZADO
    │
    ├──────────────────────────► [Cozinha]
    │                           (INSERT fila)
    │
    │
[Cozinha] ──PedidoPronto──────────────────────► [Pedidos]
                                            (status=PRONTO)

[Pedidos] ──PedidoRetirado────────────────────► [Cozinha]
                                          (DELETE FROM fila)
```

---

## Componentes de Infraestrutura

### Terraform Modules

| Módulo | Propósito | Status |
|--------|-----------|--------|
| `backend/` | S3 + DynamoDB (Terraform State) | ✅ Manter |
| `ecr/` | Container Registry | ✅ Manter |
| `kubernetes/` | EKS Cluster | ✅ Manter |
| `ingress/` | ALB Controller | ✅ Manter |
| `database/` | RDS MySQL | ❌ Remover |
| `lambda/` | Auth Function | ❌ Remover |
| `auth/` | Cognito + API Gateway | ❌ Remover |

### Kubernetes Resources

**StatefulSets:**
- `mysql-clientes` (512Mi RAM, 500m CPU, 5Gi PVC)
- `mysql-pedidos` (512Mi RAM, 500m CPU, 5Gi PVC)
- `mysql-cozinha` (512Mi RAM, 500m CPU, 5Gi PVC)
- `mongodb` (512Mi RAM, 500m CPU, 5Gi PVC)
- `rabbitmq` (512Mi RAM, 500m CPU, 5Gi PVC)

**Deployments:**
- `clientes` (256Mi RAM, 250m CPU, 1 réplica)
- `pedidos` (256Mi RAM, 250m CPU, 1 réplica)
- `cozinha` (256Mi RAM, 250m CPU, 1 réplica)
- `pagamento` (256Mi RAM, 250m CPU, 1 réplica)

**Services:**
- Tipo `ClusterIP` para comunicação interna
- Tipo `NodePort` para Minikube (30080-30083)
- `Ingress` com ALB para EKS

---

## Próximos Passos

Ver [MIGRATION-GUIDE.md](./MIGRATION-GUIDE.md) para o plano detalhado de migração.
