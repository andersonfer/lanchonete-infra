# Guia de Migração - Monólito para Microserviços

## Visão Geral

Este guia detalha o processo de migração do sistema monolítico atual (`app/autoatendimento`) para uma arquitetura de microserviços.

**Estratégia:** Migração gradual, serviço por serviço, mantendo funcionalidade em cada etapa.

**Ordem de Implementação:**
1. Clientes (mais simples, sem dependências)
2. Pagamento (introduz RabbitMQ, sem chamadas REST)
3. Pedidos (orquestrador central, REST + RabbitMQ)
4. Cozinha (completa o ciclo, depende de Pedidos)

---

## Fase 0: Preparação da Infraestrutura

### Objetivo
Preparar ambiente Kubernetes (Minikube e EKS) com databases e mensageria.

### Tarefas

#### 0.1. Criar Estrutura de Diretórios

```bash
mkdir -p services/{clientes,pedidos,cozinha,pagamento}
mkdir -p k8s/{databases,services,local,aws}
mkdir -p k8s/databases/secrets
```

#### 0.2. Manifests K8s - Databases

Criar StatefulSets para:
- MySQL (Clientes, Pedidos, Cozinha)
- MongoDB (Pagamento)
- RabbitMQ

**Arquivos:**
- `k8s/databases/secrets/mysql-clientes-secret.yaml`
- `k8s/databases/secrets/mysql-pedidos-secret.yaml`
- `k8s/databases/secrets/mysql-cozinha-secret.yaml`
- `k8s/databases/secrets/mongodb-secret.yaml`
- `k8s/databases/secrets/rabbitmq-secret.yaml`
- `k8s/databases/mysql-clientes.yaml`
- `k8s/databases/mysql-pedidos.yaml`
- `k8s/databases/mysql-cozinha.yaml`
- `k8s/databases/mongodb.yaml`
- `k8s/databases/rabbitmq.yaml`

#### 0.3. Script de Criação de Secrets

Atualizar `scripts/create-secrets.sh` para criar secrets K8s (não mais RDS).

#### 0.4. Terraform - Limpeza

Remover módulos desnecessários:
```bash
rm -rf infra/database
rm -rf infra/lambda
rm -rf infra/auth
rm -rf infra/api-gateway
```

Manter apenas:
- `infra/backend/` (Terraform state)
- `infra/ecr/` (Container registry)
- `infra/kubernetes/` (EKS cluster)
- `infra/ingress/` (ALB controller)

#### 0.5. Deploy Local (Minikube)

```bash
# Iniciar Minikube
minikube start --memory=4096 --cpus=4

# Criar secrets
./scripts/create-secrets.sh

# Deploy databases
kubectl apply -f k8s/databases/

# Aguardar databases prontos
kubectl wait --for=condition=ready pod -l app=mysql-clientes --timeout=120s
kubectl wait --for=condition=ready pod -l app=mysql-pedidos --timeout=120s
kubectl wait --for=condition=ready pod -l app=mysql-cozinha --timeout=120s
kubectl wait --for=condition=ready pod -l app=mongodb --timeout=120s
kubectl wait --for=condition=ready pod -l app=rabbitmq --timeout=120s
```

**Critérios de Sucesso:**
- ✅ Todos os 5 StatefulSets em estado `Ready`
- ✅ PVCs criados e bound
- ✅ Conexão aos bancos funcionando

---

## Fase 1: Microserviço CLIENTES

### Objetivo
Extrair funcionalidade de identificação/cadastro de clientes para serviço independente.

### 1.1. Código - Estrutura

```
services/clientes/
├── src/
│   ├── main/
│   │   ├── java/br/com/lanchonete/clientes/
│   │   │   ├── dominio/
│   │   │   │   ├── modelo/
│   │   │   │   │   ├── Cliente.java        # COPIAR de autoatendimento
│   │   │   │   │   ├── Cpf.java            # COPIAR de autoatendimento
│   │   │   │   │   └── Email.java          # COPIAR de autoatendimento
│   │   │   │   └── excecoes/
│   │   │   │       └── ClienteNaoEncontradoException.java
│   │   │   ├── aplicacao/
│   │   │   │   ├── casosdeuso/
│   │   │   │   │   ├── IdentificarCliente.java    # ADAPTAR
│   │   │   │   │   ├── CadastrarCliente.java      # ADAPTAR
│   │   │   │   │   └── BuscarClientePorCpf.java   # NOVO
│   │   │   │   └── gateways/
│   │   │   │       └── ClienteGateway.java
│   │   │   ├── infra/
│   │   │   │   ├── persistencia/
│   │   │   │   │   ├── ClienteRepository.java     # ADAPTAR de JDBC Gateway
│   │   │   │   │   └── ClienteEntity.java         # Spring Data
│   │   │   │   └── config/
│   │   │   │       └── DatabaseConfig.java
│   │   │   └── apresentacao/
│   │   │       ├── controllers/
│   │   │       │   └── ClienteController.java     # ADAPTAR
│   │   │       └── dto/
│   │   │           ├── ClienteRequest.java
│   │   │           └── ClienteResponse.java
│   │   └── resources/
│   │       ├── application.yml
│   │       └── schema.sql
│   └── test/
│       └── java/br/com/lanchonete/clientes/
├── Dockerfile
└── pom.xml
```

### 1.2. Código - Reaproveitar do Monólito

**Copiar diretamente (95% reaproveitável):**
- `Cliente.java`
- `Cpf.java`
- `Email.java`

**Adaptar (mudança de imports e contexto):**
- `IdentificarCliente.java` → remover lógica de pedidos
- `CadastrarCliente.java` → foco apenas em cliente
- `ClienteGatewayJDBC.java` → transformar em Spring Data JPA

**Criar novo:**
- `BuscarClientePorCpf.java` (usado por Pedidos via REST)

### 1.3. Schema MySQL

```sql
-- k8s/databases/init-scripts/clientes.sql
CREATE DATABASE IF NOT EXISTS clientes_db;
USE clientes_db;

CREATE TABLE cliente (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    cpf VARCHAR(11) NOT NULL UNIQUE,
    nome VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_cliente_cpf (cpf)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 1.4. Endpoints REST

| Método | Path | Request | Response | Status |
|--------|------|---------|----------|--------|
| POST | `/clientes/identificar` | `{cpf}` | `ClienteResponse` | 200/404 |
| POST | `/clientes` | `{nome, email, cpf}` | `ClienteResponse` | 201 |
| GET | `/clientes/{cpf}` | - | `ClienteResponse` | 200/404 |

### 1.5. Manifests Kubernetes

```yaml
# k8s/services/clientes-deployment.yaml
# k8s/services/clientes-service.yaml (ClusterIP)
# k8s/local/clientes-service-nodeport.yaml (NodePort 30083)
```

### 1.6. Testes

```bash
cd services/clientes
mvn clean test  # Coverage > 80%
```

### 1.7. Deploy Local

```bash
# Build
cd services/clientes
mvn clean install
docker build -t clientes:latest .

# Load no Minikube
minikube image load clientes:latest

# Deploy
kubectl apply -f k8s/services/clientes-deployment.yaml
kubectl apply -f k8s/local/clientes-service-nodeport.yaml

# Teste
curl http://$(minikube ip):30083/clientes/12345678900
```

**Critérios de Sucesso:**
- ✅ Pod `clientes` em estado `Running`
- ✅ Endpoints respondem corretamente
- ✅ Dados persistem no MySQL

---

## Fase 2: Microserviço PAGAMENTO

### Objetivo
Criar serviço de pagamento com mock (80% aprovação) e introduzir RabbitMQ.

### 2.1. Código - Estrutura

```
services/pagamento/
├── src/
│   ├── main/
│   │   ├── java/br/com/lanchonete/pagamento/
│   │   │   ├── dominio/
│   │   │   │   ├── modelo/
│   │   │   │   │   ├── Pagamento.java
│   │   │   │   │   └── StatusPagamento.java
│   │   │   │   └── servicos/
│   │   │   │       └── MockPagamentoService.java  # Random 0-99
│   │   │   ├── aplicacao/
│   │   │   │   ├── casosdeuso/
│   │   │   │   │   └── ProcessarPagamento.java
│   │   │   │   └── eventos/
│   │   │   │       ├── PedidoCriadoEvent.java
│   │   │   │       ├── PagamentoAprovadoEvent.java
│   │   │   │       └── PagamentoRejeitadoEvent.java
│   │   │   ├── infra/
│   │   │   │   ├── persistencia/
│   │   │   │   │   ├── PagamentoRepository.java  # MongoDB
│   │   │   │   │   └── PagamentoDocument.java
│   │   │   │   └── mensageria/
│   │   │   │       ├── RabbitMQConfig.java
│   │   │   │       ├── PedidoConsumer.java        # Consome PedidoCriado
│   │   │   │       └── PagamentoPublisher.java    # Publica aprovado/rejeitado
│   │   │   └── apresentacao/
│   │   │       └── controllers/
│   │   │           └── PagamentoController.java   # Interno (opcional)
│   │   └── resources/
│   │       └── application.yml
│   └── test/
├── Dockerfile
└── pom.xml
```

### 2.2. Dependências Maven

```xml
<!-- pom.xml -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-mongodb</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-amqp</artifactId>
</dependency>
```

### 2.3. Schema MongoDB

```javascript
// Collection: pagamentos
{
  _id: ObjectId("..."),
  pedidoId: 123,
  valor: 45.90,
  status: "APROVADO",  // ou "REJEITADO"
  createdAt: ISODate("2024-10-15T10:30:00Z")
}
```

### 2.4. RabbitMQ - Configuração

```java
// RabbitMQConfig.java
@Configuration
public class RabbitMQConfig {

    // Exchange para eventos de pedidos
    @Bean
    public TopicExchange pedidoExchange() {
        return new TopicExchange("pedido.events");
    }

    // Exchange para eventos de pagamento
    @Bean
    public TopicExchange pagamentoExchange() {
        return new TopicExchange("pagamento.events");
    }

    // Fila para receber PedidoCriado
    @Bean
    public Queue pedidoCriadoQueue() {
        return new Queue("pagamento.pedido-criado");
    }

    // Binding
    @Bean
    public Binding pedidoCriadoBinding() {
        return BindingBuilder
            .bind(pedidoCriadoQueue())
            .to(pedidoExchange())
            .with("pedido.criado");
    }
}
```

### 2.5. Eventos

**Consumir:**
- Queue: `pagamento.pedido-criado`
- Event: `PedidoCriadoEvent {pedidoId, valor, cpf}`

**Publicar:**
- Exchange: `pagamento.events`
- Routing Key: `pagamento.aprovado` ou `pagamento.rejeitado`
- Event: `PagamentoAprovadoEvent {pedidoId}` ou `PagamentoRejeitadoEvent {pedidoId}`

### 2.6. Mock de Aprovação

```java
public class MockPagamentoService {

    private final Random random = new Random();

    public StatusPagamento processar(BigDecimal valor) {
        int chance = random.nextInt(100);
        return chance < 80 ? StatusPagamento.APROVADO : StatusPagamento.REJEITADO;
    }
}
```

### 2.7. Deploy Local

```bash
# Build
cd services/pagamento
mvn clean install
docker build -t pagamento:latest .

# Load no Minikube
minikube image load pagamento:latest

# Deploy
kubectl apply -f k8s/services/pagamento-deployment.yaml
kubectl apply -f k8s/local/pagamento-service-nodeport.yaml
```

**Critérios de Sucesso:**
- ✅ Pod `pagamento` em estado `Running`
- ✅ Conectado ao MongoDB
- ✅ Conectado ao RabbitMQ
- ✅ Consome eventos de `pagamento.pedido-criado` (testar via RabbitMQ Management UI)

---

## Fase 3: Microserviço PEDIDOS

### Objetivo
Orquestrador central que integra Clientes (REST) e Pagamento/Cozinha (RabbitMQ).

### 3.1. Código - Estrutura

```
services/pedidos/
├── src/
│   ├── main/
│   │   ├── java/br/com/lanchonete/pedidos/
│   │   │   ├── dominio/
│   │   │   │   ├── modelo/
│   │   │   │   │   ├── Pedido.java          # COPIAR + ADAPTAR
│   │   │   │   │   ├── ItemPedido.java      # COPIAR
│   │   │   │   │   ├── Produto.java         # COPIAR
│   │   │   │   │   ├── StatusPedido.java    # NOVO ENUM (unificado)
│   │   │   │   │   ├── NumeroPedido.java    # COPIAR
│   │   │   │   │   └── Preco.java           # COPIAR
│   │   │   ├── aplicacao/
│   │   │   │   ├── casosdeuso/
│   │   │   │   │   ├── RealizarPedido.java          # ADAPTAR (checkout)
│   │   │   │   │   ├── ListarPedidos.java           # ADAPTAR
│   │   │   │   │   ├── BuscarPedidoPorId.java       # NOVO
│   │   │   │   │   ├── RetirarPedido.java           # ADAPTAR
│   │   │   │   │   └── AtualizarStatusPedido.java   # ADAPTAR
│   │   │   │   ├── eventos/
│   │   │   │   │   ├── PedidoCriadoEvent.java
│   │   │   │   │   ├── PagamentoAprovadoEvent.java
│   │   │   │   │   ├── PagamentoRejeitadoEvent.java
│   │   │   │   │   ├── PedidoProntoEvent.java
│   │   │   │   │   └── PedidoRetiradoEvent.java
│   │   │   │   └── integracao/
│   │   │   │       └── ClienteClient.java           # Feign Client
│   │   │   ├── infra/
│   │   │   │   ├── persistencia/
│   │   │   │   │   ├── PedidoRepository.java
│   │   │   │   │   ├── ProdutoRepository.java
│   │   │   │   │   └── (entities)
│   │   │   │   ├── mensageria/
│   │   │   │   │   ├── RabbitMQConfig.java
│   │   │   │   │   ├── PedidoPublisher.java
│   │   │   │   │   └── PagamentoConsumer.java
│   │   │   │   └── rest/
│   │   │   │       └── ClienteClientImpl.java       # OpenFeign
│   │   │   └── apresentacao/
│   │   │       ├── controllers/
│   │   │       │   ├── PedidoController.java
│   │   │       │   └── ProdutoController.java
│   │   │       └── dto/
│   │   └── resources/
│   │       ├── application.yml
│   │       └── schema.sql
│   └── test/
├── Dockerfile
└── pom.xml
```

### 3.2. Dependências Maven

```xml
<!-- pom.xml -->
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-openfeign</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-amqp</artifactId>
</dependency>
```

### 3.3. Schema MySQL

```sql
-- k8s/databases/init-scripts/pedidos.sql
CREATE DATABASE IF NOT EXISTS pedidos_db;
USE pedidos_db;

CREATE TABLE produto (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(255) NOT NULL UNIQUE,
    descricao VARCHAR(255),
    preco DECIMAL(10,2) NOT NULL,
    categoria VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_produto_categoria (categoria)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE pedido (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    numero_pedido VARCHAR(20) NOT NULL UNIQUE,
    cpf_cliente VARCHAR(11),  -- Pode ser NULL (anônimo)
    status VARCHAR(50) NOT NULL DEFAULT 'CRIADO',
    valor_total DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_pedido_status (status),
    INDEX idx_pedido_cpf (cpf_cliente)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE item_pedido (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    pedido_id BIGINT NOT NULL,
    produto_id BIGINT NOT NULL,
    quantidade INT NOT NULL,
    valor_unitario DECIMAL(10,2) NOT NULL,  -- SNAPSHOT de preço
    valor_total DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (pedido_id) REFERENCES pedido(id),
    FOREIGN KEY (produto_id) REFERENCES produto(id),
    INDEX idx_item_pedido_pedido_id (pedido_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 3.4. StatusPedido Unificado

```java
public enum StatusPedido {
    CRIADO,           // Pedido criado, aguardando pagamento
    REALIZADO,        // Pagamento aprovado
    CANCELADO,        // Pagamento rejeitado
    EM_PREPARACAO,    // Cozinha iniciou preparo
    PRONTO,           // Cozinha finalizou
    FINALIZADO        // Cliente retirou
}
```

### 3.5. Integração REST com Clientes

```java
@FeignClient(name = "clientes-service", url = "${clientes.service.url}")
public interface ClienteClient {

    @GetMapping("/clientes/{cpf}")
    ClienteResponse buscarPorCpf(@PathVariable String cpf);
}
```

**application.yml:**
```yaml
clientes:
  service:
    url: http://clientes-service:8083  # EKS (DNS interno)
    # url: http://$(minikube ip):30083  # Minikube (substituir dinamicamente)
```

### 3.6. Fluxo de Checkout

```java
@Service
public class RealizarPedido {

    public PedidoResponse executar(CheckoutRequest request) {
        // 1. Validar cliente (se cpf fornecido)
        if (request.getCpfCliente() != null) {
            try {
                clienteClient.buscarPorCpf(request.getCpfCliente());
            } catch (FeignException.NotFound e) {
                throw new ClienteNaoEncontradoException(request.getCpfCliente());
            }
        }

        // 2. Criar pedido (status=CRIADO)
        Pedido pedido = Pedido.criar(
            request.getCpfCliente(),
            request.getItens(),
            StatusPedido.CRIADO
        );
        pedido = pedidoRepository.save(pedido);

        // 3. Publicar evento PedidoCriado
        PedidoCriadoEvent evento = new PedidoCriadoEvent(
            pedido.getId(),
            pedido.getValorTotal(),
            pedido.getCpfCliente()
        );
        pedidoPublisher.publicarPedidoCriado(evento);

        return PedidoResponse.from(pedido);
    }
}
```

### 3.7. Eventos RabbitMQ

**Publicar:**
- `PedidoCriado` → `pedido.events` (routing: `pedido.criado`)
- `PedidoRetirado` → `pedido.events` (routing: `pedido.retirado`)

**Consumir:**
- `PagamentoAprovado` → `pedidos.pagamento-aprovado` (atualiza status → REALIZADO)
- `PagamentoRejeitado` → `pedidos.pagamento-rejeitado` (atualiza status → CANCELADO)
- `PedidoPronto` → `pedidos.pedido-pronto` (atualiza status → PRONTO)

### 3.8. Endpoints REST

| Método | Path | Descrição |
|--------|------|-----------|
| POST | `/pedidos/checkout` | Criar pedido |
| GET | `/pedidos` | Listar pedidos |
| GET | `/pedidos/{id}` | Buscar pedido por ID |
| PATCH | `/pedidos/{id}/retirar` | Marcar como retirado |
| GET | `/produtos` | Listar produtos |
| GET | `/produtos/categoria/{categoria}` | Buscar por categoria |

### 3.9. Deploy Local

```bash
# Build
cd services/pedidos
mvn clean install
docker build -t pedidos:latest .

# Load no Minikube
minikube image load pedidos:latest

# Deploy
kubectl apply -f k8s/services/pedidos-deployment.yaml
kubectl apply -f k8s/local/pedidos-service-nodeport.yaml

# Teste E2E
curl -X POST http://$(minikube ip):30080/pedidos/checkout \
  -H "Content-Type: application/json" \
  -d '{
    "cpfCliente": "12345678900",
    "itens": [
      {"produtoId": 1, "quantidade": 2}
    ]
  }'
```

**Critérios de Sucesso:**
- ✅ Checkout cria pedido
- ✅ Evento `PedidoCriado` publicado no RabbitMQ
- ✅ Pagamento processa (80% aprovado)
- ✅ Status atualizado para `REALIZADO` ou `CANCELADO`

---

## Fase 4: Microserviço COZINHA

### Objetivo
Gerenciar fila de produção e status de preparo.

### 4.1. Código - Estrutura

```
services/cozinha/
├── src/
│   ├── main/
│   │   ├── java/br/com/lanchonete/cozinha/
│   │   │   ├── dominio/
│   │   │   │   ├── modelo/
│   │   │   │   │   ├── FilaCozinha.java
│   │   │   │   │   └── StatusFila.java
│   │   │   ├── aplicacao/
│   │   │   │   ├── casosdeuso/
│   │   │   │   │   ├── ListarFila.java
│   │   │   │   │   ├── IniciarPreparo.java
│   │   │   │   │   └── MarcarComoPronto.java
│   │   │   │   ├── eventos/
│   │   │   │   │   ├── PagamentoAprovadoEvent.java
│   │   │   │   │   ├── PedidoRetiradoEvent.java
│   │   │   │   │   └── PedidoProntoEvent.java
│   │   │   │   └── integracao/
│   │   │   │       └── PedidoClient.java           # Feign Client
│   │   │   ├── infra/
│   │   │   │   ├── persistencia/
│   │   │   │   │   ├── FilaCozinhaRepository.java
│   │   │   │   │   └── FilaCozinhaEntity.java
│   │   │   │   ├── mensageria/
│   │   │   │   │   ├── RabbitMQConfig.java
│   │   │   │   │   ├── PagamentoConsumer.java     # PagamentoAprovado
│   │   │   │   │   ├── PedidoConsumer.java        # PedidoRetirado
│   │   │   │   │   └── CozinhaPublisher.java      # PedidoPronto
│   │   │   │   └── rest/
│   │   │   │       └── PedidoClientImpl.java
│   │   │   └── apresentacao/
│   │   │       ├── controllers/
│   │   │       │   └── CozinhaController.java
│   │   │       └── dto/
│   │   └── resources/
│   │       ├── application.yml
│   │       └── schema.sql
│   └── test/
├── Dockerfile
└── pom.xml
```

### 4.2. Schema MySQL

```sql
-- k8s/databases/init-scripts/cozinha.sql
CREATE DATABASE IF NOT EXISTS cozinha_db;
USE cozinha_db;

CREATE TABLE fila_cozinha (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    pedido_id BIGINT NOT NULL UNIQUE,
    pedido_numero VARCHAR(20) NOT NULL,
    cliente_nome VARCHAR(255),  -- Denormalizado
    status VARCHAR(50) NOT NULL DEFAULT 'RECEBIDO',
    itens JSON COMMENT 'Array: [{nome, quantidade}]',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_status (status),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 4.3. StatusFila

```java
public enum StatusFila {
    RECEBIDO,       // Pagamento aprovado, aguardando cozinha
    EM_PREPARO,     // Cozinha iniciou
    PRONTO,         // Pronto para retirada
    REMOVIDO        // Cliente retirou (soft delete)
}
```

### 4.4. Integração REST com Pedidos

```java
@FeignClient(name = "pedidos-service", url = "${pedidos.service.url}")
public interface PedidoClient {

    @GetMapping("/pedidos/{id}")
    PedidoResponse buscarPorId(@PathVariable Long id);
}
```

Usado para buscar detalhes do pedido ao inserir na fila.

### 4.5. Eventos RabbitMQ

**Consumir:**
- `PagamentoAprovado` → Insere pedido na fila (status=RECEBIDO)
- `PedidoRetirado` → Remove da fila (status=REMOVIDO ou DELETE)

**Publicar:**
- `PedidoPronto` → Notifica Pedidos que está pronto

### 4.6. Fluxo de Preparo

1. **Pagamento Aprovado:**
   - Consome evento
   - Busca detalhes via REST: `GET /pedidos/{id}`
   - Insere na fila com status=RECEBIDO

2. **Iniciar Preparo:**
   - `POST /cozinha/fila/{id}/iniciar`
   - Atualiza status → EM_PREPARO

3. **Marcar Pronto:**
   - `POST /cozinha/fila/{id}/pronto`
   - Atualiza status → PRONTO
   - Publica evento `PedidoPronto`

4. **Retirada:**
   - Consome evento `PedidoRetirado`
   - Remove da fila (DELETE ou status=REMOVIDO)

### 4.7. Endpoints REST

| Método | Path | Descrição |
|--------|------|-----------|
| GET | `/cozinha/fila` | Listar fila |
| POST | `/cozinha/fila/{id}/iniciar` | Iniciar preparo |
| POST | `/cozinha/fila/{id}/pronto` | Marcar pronto |

### 4.8. Deploy Local

```bash
# Build
cd services/cozinha
mvn clean install
docker build -t cozinha:latest .

# Load no Minikube
minikube image load cozinha:latest

# Deploy
kubectl apply -f k8s/services/cozinha-deployment.yaml
kubectl apply -f k8s/local/cozinha-service-nodeport.yaml

# Teste
curl http://$(minikube ip):30082/cozinha/fila
```

**Critérios de Sucesso:**
- ✅ Fila recebe pedidos após `PagamentoAprovado`
- ✅ Status atualiza corretamente
- ✅ Evento `PedidoPronto` publicado
- ✅ Pedidos removem após retirada

---

## Fase 5: Integração e Testes E2E

### 5.1. Fluxo Completo (Minikube)

```bash
#!/bin/bash
# scripts/test-fluxo-completo.sh

MINIKUBE_IP=$(minikube ip)

echo "1️⃣ Identificar cliente"
curl -X POST http://$MINIKUBE_IP:30083/clientes/identificar \
  -H "Content-Type: application/json" \
  -d '{"cpf": "12345678900"}'

echo "\n2️⃣ Criar pedido (checkout)"
PEDIDO_RESPONSE=$(curl -s -X POST http://$MINIKUBE_IP:30080/pedidos/checkout \
  -H "Content-Type: application/json" \
  -d '{
    "cpfCliente": "12345678900",
    "itens": [{"produtoId": 1, "quantidade": 2}]
  }')

PEDIDO_ID=$(echo $PEDIDO_RESPONSE | jq -r '.id')
echo "Pedido criado: $PEDIDO_ID"

echo "\n3️⃣ Aguardar processamento pagamento (3s)"
sleep 3

echo "\n4️⃣ Verificar status pedido"
curl http://$MINIKUBE_IP:30080/pedidos/$PEDIDO_ID | jq '.status'

echo "\n5️⃣ Verificar fila cozinha"
curl http://$MINIKUBE_IP:30082/cozinha/fila | jq '.[0]'

echo "\n6️⃣ Iniciar preparo"
FILA_ID=$(curl -s http://$MINIKUBE_IP:30082/cozinha/fila | jq -r '.[0].id')
curl -X POST http://$MINIKUBE_IP:30082/cozinha/fila/$FILA_ID/iniciar

echo "\n7️⃣ Marcar como pronto"
curl -X POST http://$MINIKUBE_IP:30082/cozinha/fila/$FILA_ID/pronto

echo "\n8️⃣ Retirar pedido"
curl -X PATCH http://$MINIKUBE_IP:30080/pedidos/$PEDIDO_ID/retirar

echo "\n✅ Fluxo completo executado!"
```

### 5.2. Validações

- ✅ Cliente criado/identificado
- ✅ Pedido criado com status=CRIADO
- ✅ Pagamento processado (80% aprovado)
- ✅ Status atualizado para REALIZADO ou CANCELADO
- ✅ Se aprovado, pedido aparece na fila da cozinha
- ✅ Status de preparo atualiza corretamente
- ✅ Evento PedidoPronto recebido por Pedidos
- ✅ Retirada remove da fila

### 5.3. RabbitMQ Management UI

```bash
# Port-forward RabbitMQ Management
kubectl port-forward svc/rabbitmq-service 15672:15672

# Acessar: http://localhost:15672
# Usuário: guest / Senha: guest
```

Verificar:
- Exchanges criados: `pedido.events`, `pagamento.events`, `cozinha.events`
- Filas criadas e bindings corretos
- Mensagens sendo publicadas/consumidas

---

## Fase 6: Deploy EKS (Demonstração)

### 6.1. Provisionar Infraestrutura

```bash
# 1. Backend (state)
cd infra/backend
terraform init
terraform apply -auto-approve

# 2. ECR
cd ../ecr
terraform init
terraform apply -auto-approve

# 3. EKS Cluster
cd ../kubernetes
terraform init
terraform apply -auto-approve  # ~15min

# 4. Configurar kubectl
aws eks update-kubeconfig --name lanchonete-cluster --region us-east-1

# 5. ALB Controller
cd ../ingress
terraform init
terraform apply -auto-approve
```

### 6.2. Build e Push Imagens

```bash
./scripts/build-and-push.sh
```

### 6.3. Deploy K8s

```bash
# 1. Criar secrets
./scripts/create-secrets.sh

# 2. Deploy databases
kubectl apply -f k8s/databases/

# 3. Aguardar databases
kubectl wait --for=condition=ready pod -l app=mysql-clientes --timeout=300s
kubectl wait --for=condition=ready pod -l app=mysql-pedidos --timeout=300s
kubectl wait --for=condition=ready pod -l app=mysql-cozinha --timeout=300s
kubectl wait --for=condition=ready pod -l app=mongodb --timeout=300s
kubectl wait --for=condition=ready pod -l app=rabbitmq --timeout=300s

# 4. Deploy services
kubectl apply -f k8s/services/

# 5. Deploy Ingress (ALB)
kubectl apply -f k8s/aws/ingress.yaml

# 6. Aguardar ALB provisionar (~3min)
kubectl wait --for=condition=available --timeout=300s ingress/lanchonete-ingress

# 7. Obter URL do ALB
ALB_URL=$(kubectl get ingress lanchonete-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Aplicação disponível em: http://$ALB_URL"
```

### 6.4. Teste no EKS

```bash
# Substituir $ALB_URL pela URL real
curl http://$ALB_URL/clientes/12345678900
curl http://$ALB_URL/pedidos
curl http://$ALB_URL/cozinha/fila
```

---

## Checklist Final

### Código
- [ ] 4 microserviços implementados
- [ ] Clean Architecture mantida
- [ ] Testes unitários (coverage > 80%)
- [ ] Dockerfiles criados

### Infraestrutura
- [ ] Terraform modules atualizados
- [ ] 5 StatefulSets funcionando
- [ ] Secrets criados via script
- [ ] Ingress com ALB configurado

### Comunicação
- [ ] REST: Pedidos → Clientes
- [ ] REST: Cozinha → Pedidos
- [ ] RabbitMQ: 5 eventos implementados
- [ ] Feign Clients funcionando

### Deployment
- [ ] Minikube: 4 serviços rodando
- [ ] EKS: 4 serviços rodando
- [ ] CI/CD atualizado (GitHub Actions)

### Testes
- [ ] Fluxo E2E completo funcionando
- [ ] RabbitMQ publicando/consumindo eventos
- [ ] Dados persistindo nos bancos

---

## Próximos Passos

Após conclusão da migração:
1. Documentar APIs (Swagger/OpenAPI)
2. Implementar health checks
3. Adicionar observabilidade (logs estruturados)
4. Otimizar recursos K8s
5. Preparar demo/apresentação
