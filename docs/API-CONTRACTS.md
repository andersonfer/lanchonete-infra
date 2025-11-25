# Contratos de API - Sistema Lanchonete

## Visão Geral

Este documento define os contratos de comunicação entre microserviços:
- **REST APIs:** Endpoints HTTP síncronos
- **Eventos RabbitMQ:** Mensageria assíncrona

---

## REST APIs

### 1. Serviço de Clientes (Port 8083)

#### Base URL
- **Minikube:** `http://<minikube-ip>:30083`
- **EKS:** `http://<alb-url>/clientes`

#### Endpoints

##### POST /clientes/identificar
Identifica um cliente existente por CPF.

**Request:**
```json
{
  "cpf": "12345678900"
}
```

**Response 200 OK:**
```json
{
  "id": 1,
  "cpf": "12345678900",
  "nome": "João Silva",
  "email": "joao@email.com"
}
```

**Response 404 Not Found:**
```json
{
  "error": "Cliente não encontrado",
  "cpf": "12345678900"
}
```

---

##### POST /clientes
Cadastra um novo cliente.

**Request:**
```json
{
  "cpf": "12345678900",
  "nome": "João Silva",
  "email": "joao@email.com"
}
```

**Response 201 Created:**
```json
{
  "id": 1,
  "cpf": "12345678900",
  "nome": "João Silva",
  "email": "joao@email.com"
}
```

**Response 400 Bad Request:**
```json
{
  "error": "CPF inválido",
  "details": "CPF deve conter 11 dígitos"
}
```

**Response 409 Conflict:**
```json
{
  "error": "CPF já cadastrado",
  "cpf": "12345678900"
}
```

---

##### GET /clientes/{cpf}
Busca cliente por CPF (usado por Pedidos via Feign).

**Path Parameter:**
- `cpf` (string): CPF sem pontuação

**Response 200 OK:**
```json
{
  "id": 1,
  "cpf": "12345678900",
  "nome": "João Silva",
  "email": "joao@email.com"
}
```

**Response 404 Not Found:**
```json
{
  "error": "Cliente não encontrado",
  "cpf": "12345678900"
}
```

---

### 2. Serviço de Pedidos (Port 8080)

#### Base URL
- **Minikube:** `http://<minikube-ip>:30080`
- **EKS:** `http://<alb-url>/pedidos`

#### Endpoints

##### POST /pedidos/checkout
Cria um novo pedido.

**Request:**
```json
{
  "cpfCliente": "12345678900",  // Opcional (null = anônimo)
  "itens": [
    {
      "produtoId": 1,
      "quantidade": 2
    },
    {
      "produtoId": 3,
      "quantidade": 1
    }
  ]
}
```

**Response 201 Created:**
```json
{
  "id": 123,
  "numeroPedido": "PED-000123",
  "cpfCliente": "12345678900",
  "status": "CRIADO",
  "valorTotal": 45.90,
  "itens": [
    {
      "produtoNome": "X-Burger",
      "quantidade": 2,
      "valorUnitario": 15.90,
      "valorTotal": 31.80
    },
    {
      "produtoNome": "Coca-Cola",
      "quantidade": 1,
      "valorUnitario": 7.00,
      "valorTotal": 7.00
    }
  ],
  "dataCriacao": "2024-10-15T14:30:00Z"
}
```

**Response 400 Bad Request:**
```json
{
  "error": "Pedido inválido",
  "details": "Deve conter pelo menos um item"
}
```

**Response 404 Not Found:**
```json
{
  "error": "Cliente não encontrado",
  "cpf": "12345678900"
}
```

---

##### GET /pedidos
Lista todos os pedidos.

**Query Parameters (opcionais):**
- `status` (string): Filtrar por status (CRIADO, REALIZADO, etc.)

**Response 200 OK:**
```json
[
  {
    "id": 123,
    "numeroPedido": "PED-000123",
    "cpfCliente": "12345678900",
    "status": "REALIZADO",
    "valorTotal": 45.90,
    "dataCriacao": "2024-10-15T14:30:00Z"
  },
  {
    "id": 124,
    "numeroPedido": "PED-000124",
    "cpfCliente": null,
    "status": "CRIADO",
    "valorTotal": 25.00,
    "dataCriacao": "2024-10-15T14:35:00Z"
  }
]
```

---

##### GET /pedidos/{id}
Busca pedido por ID (usado por Cozinha via Feign).

**Path Parameter:**
- `id` (long): ID do pedido

**Response 200 OK:**
```json
{
  "id": 123,
  "numeroPedido": "PED-000123",
  "cpfCliente": "12345678900",
  "clienteNome": "João Silva",
  "status": "REALIZADO",
  "valorTotal": 45.90,
  "itens": [
    {
      "produtoNome": "X-Burger",
      "quantidade": 2,
      "valorUnitario": 15.90,
      "valorTotal": 31.80
    }
  ],
  "dataCriacao": "2024-10-15T14:30:00Z"
}
```

**Response 404 Not Found:**
```json
{
  "error": "Pedido não encontrado",
  "id": 123
}
```

---

##### PATCH /pedidos/{id}/retirar
Marca pedido como retirado (status → FINALIZADO).

**Path Parameter:**
- `id` (long): ID do pedido

**Response 200 OK:**
```json
{
  "id": 123,
  "numeroPedido": "PED-000123",
  "status": "FINALIZADO",
  "dataCriacao": "2024-10-15T14:30:00Z",
  "dataFinalizacao": "2024-10-15T15:00:00Z"
}
```

**Response 400 Bad Request:**
```json
{
  "error": "Pedido não está pronto para retirada",
  "status": "EM_PREPARACAO"
}
```

---

##### GET /produtos
Lista todos os produtos.

**Response 200 OK:**
```json
[
  {
    "id": 1,
    "nome": "X-Burger",
    "descricao": "Hambúrguer com queijo",
    "preco": 15.90,
    "categoria": "LANCHE"
  },
  {
    "id": 2,
    "nome": "Batata Frita",
    "descricao": "Porção média",
    "preco": 10.00,
    "categoria": "ACOMPANHAMENTO"
  }
]
```

---

##### GET /produtos/categoria/{categoria}
Busca produtos por categoria.

**Path Parameter:**
- `categoria` (enum): LANCHE, ACOMPANHAMENTO, BEBIDA, SOBREMESA

**Response 200 OK:**
```json
[
  {
    "id": 1,
    "nome": "X-Burger",
    "descricao": "Hambúrguer com queijo",
    "preco": 15.90,
    "categoria": "LANCHE"
  },
  {
    "id": 4,
    "nome": "X-Bacon",
    "descricao": "Hambúrguer com bacon",
    "preco": 18.90,
    "categoria": "LANCHE"
  }
]
```

---

### 3. Serviço de Cozinha (Port 8082)

#### Base URL
- **Minikube:** `http://<minikube-ip>:30082`
- **EKS:** `http://<alb-url>/cozinha`

#### Endpoints

##### GET /cozinha/fila
Lista fila de produção.

**Query Parameters (opcionais):**
- `status` (string): Filtrar por status (RECEBIDO, EM_PREPARO, PRONTO)

**Response 200 OK:**
```json
[
  {
    "id": 1,
    "pedidoId": 123,
    "pedidoNumero": "PED-000123",
    "clienteNome": "João Silva",
    "status": "RECEBIDO",
    "itens": [
      {"nome": "X-Burger", "quantidade": 2},
      {"nome": "Coca-Cola", "quantidade": 1}
    ],
    "createdAt": "2024-10-15T14:30:00Z"
  },
  {
    "id": 2,
    "pedidoId": 124,
    "pedidoNumero": "PED-000124",
    "clienteNome": null,
    "status": "EM_PREPARO",
    "itens": [
      {"nome": "X-Bacon", "quantidade": 1}
    ],
    "createdAt": "2024-10-15T14:35:00Z"
  }
]
```

---

##### POST /cozinha/fila/{id}/iniciar
Inicia preparo de um pedido (status → EM_PREPARO).

**Path Parameter:**
- `id` (long): ID da fila

**Response 200 OK:**
```json
{
  "id": 1,
  "pedidoId": 123,
  "status": "EM_PREPARO",
  "updatedAt": "2024-10-15T14:40:00Z"
}
```

**Response 400 Bad Request:**
```json
{
  "error": "Pedido já está em preparo",
  "status": "EM_PREPARO"
}
```

---

##### POST /cozinha/fila/{id}/pronto
Marca pedido como pronto (status → PRONTO).

**Path Parameter:**
- `id` (long): ID da fila

**Response 200 OK:**
```json
{
  "id": 1,
  "pedidoId": 123,
  "status": "PRONTO",
  "updatedAt": "2024-10-15T14:50:00Z"
}
```

**Response 400 Bad Request:**
```json
{
  "error": "Pedido não está em preparo",
  "status": "RECEBIDO"
}
```

---

### 4. Serviço de Pagamento (Port 8081)

**Observação:** Este serviço não expõe APIs públicas. Toda comunicação é via RabbitMQ (assíncrona).

Endpoint opcional para debug/monitoring:

##### GET /pagamentos/{pedidoId}
Consulta status de pagamento de um pedido.

**Path Parameter:**
- `pedidoId` (long): ID do pedido

**Response 200 OK:**
```json
{
  "id": "64a1b2c3d4e5f6g7h8i9j0k1",
  "pedidoId": 123,
  "valor": 45.90,
  "status": "APROVADO",
  "createdAt": "2024-10-15T14:30:05Z"
}
```

---

## Eventos RabbitMQ

### Exchanges

| Nome | Tipo | Descrição |
|------|------|-----------|
| `pedido.events` | topic | Eventos relacionados a pedidos |
| `pagamento.events` | topic | Eventos relacionados a pagamentos |
| `cozinha.events` | topic | Eventos relacionados à cozinha |

---

### 1. PedidoCriado

**Publisher:** Pedidos
**Exchange:** `pedido.events`
**Routing Key:** `pedido.criado`
**Subscribers:** Pagamento

**Payload:**
```json
{
  "pedidoId": 123,
  "valor": 45.90,
  "cpfCliente": "12345678900",
  "timestamp": "2024-10-15T14:30:00Z"
}
```

**Descrição:**
Publicado quando um pedido é criado via checkout. Pagamento consome e processa.

---

### 2. PagamentoAprovado

**Publisher:** Pagamento
**Exchange:** `pagamento.events`
**Routing Key:** `pagamento.aprovado`
**Subscribers:** Pedidos, Cozinha

**Payload:**
```json
{
  "pedidoId": 123,
  "timestamp": "2024-10-15T14:30:05Z"
}
```

**Descrição:**
Publicado quando pagamento é aprovado (mock < 80).
- **Pedidos:** Atualiza status → REALIZADO
- **Cozinha:** Insere na fila (status=RECEBIDO)

---

### 3. PagamentoRejeitado

**Publisher:** Pagamento
**Exchange:** `pagamento.events`
**Routing Key:** `pagamento.rejeitado`
**Subscribers:** Pedidos

**Payload:**
```json
{
  "pedidoId": 123,
  "motivo": "Simulação de falha (mock >= 80)",
  "timestamp": "2024-10-15T14:30:05Z"
}
```

**Descrição:**
Publicado quando pagamento é rejeitado (mock >= 80).
- **Pedidos:** Atualiza status → CANCELADO

---

### 4. PedidoPronto

**Publisher:** Cozinha
**Exchange:** `cozinha.events`
**Routing Key:** `cozinha.pedido-pronto`
**Subscribers:** Pedidos

**Payload:**
```json
{
  "pedidoId": 123,
  "filaId": 1,
  "timestamp": "2024-10-15T14:50:00Z"
}
```

**Descrição:**
Publicado quando cozinha finaliza preparo.
- **Pedidos:** Atualiza status → PRONTO

---

### 5. PedidoRetirado

**Publisher:** Pedidos
**Exchange:** `pedido.events`
**Routing Key:** `pedido.retirado`
**Subscribers:** Cozinha

**Payload:**
```json
{
  "pedidoId": 123,
  "timestamp": "2024-10-15T15:00:00Z"
}
```

**Descrição:**
Publicado quando cliente retira pedido.
- **Cozinha:** Remove da fila (DELETE ou status=REMOVIDO)

---

## Configuração RabbitMQ

### Filas e Bindings

#### Serviço de Pagamento

**Queues:**
- `pagamento.pedido-criado`

**Bindings:**
```
Exchange: pedido.events
Routing Key: pedido.criado
Queue: pagamento.pedido-criado
```

---

#### Serviço de Pedidos

**Queues:**
- `pedidos.pagamento-aprovado`
- `pedidos.pagamento-rejeitado`
- `pedidos.pedido-pronto`

**Bindings:**
```
Exchange: pagamento.events
Routing Key: pagamento.aprovado
Queue: pedidos.pagamento-aprovado

Exchange: pagamento.events
Routing Key: pagamento.rejeitado
Queue: pedidos.pagamento-rejeitado

Exchange: cozinha.events
Routing Key: cozinha.pedido-pronto
Queue: pedidos.pedido-pronto
```

---

#### Serviço de Cozinha

**Queues:**
- `cozinha.pagamento-aprovado`
- `cozinha.pedido-retirado`

**Bindings:**
```
Exchange: pagamento.events
Routing Key: pagamento.aprovado
Queue: cozinha.pagamento-aprovado

Exchange: pedido.events
Routing Key: pedido.retirado
Queue: cozinha.pedido-retirado
```

---

## Diagramas de Sequência

### Fluxo 1: Pedido Aprovado (Happy Path)

```
Cliente          Pedidos         Clientes        RabbitMQ        Pagamento       Cozinha
  │                │                │               │                │              │
  ├─POST checkout──►               │               │                │              │
  │                ├─GET /clientes/{cpf}──────────►│                │              │
  │                ◄───200 OK───────┤               │                │              │
  │                │                │               │                │              │
  │                ├─INSERT pedido (status=CRIADO) │                │              │
  │◄──201 Created──┤                │               │                │              │
  │                │                │               │                │              │
  │                ├─PedidoCriado──────────────────►├───consome─────►              │
  │                │                │               │                ├─mock (< 80) │
  │                │                │               │                ├─INSERT Mongo│
  │                │                │               │◄─PagamentoAprovado────────────┤
  │                ◄─consome────────┤               │                │              │
  │                ├─UPDATE (status=REALIZADO)     │                │              │
  │                │                │               │                │              ◄─consome
  │                │                │               │                │              ├─GET /pedidos/{id}
  │                │                │               │                │              ◄────────┤
  │                │                │               │                │              ├─INSERT fila
  │                │                │               │                │              │
```

### Fluxo 2: Pedido Rejeitado

```
Cliente          Pedidos         RabbitMQ        Pagamento
  │                │                │                │
  ├─POST checkout──►               │                │
  │◄──201 Created──┤                │                │
  │                ├─PedidoCriado──────────────────►├─mock (>= 80)
  │                │                │◄─PagamentoRejeitado────────┤
  │                ◄─consome────────┤                │
  │                ├─UPDATE (status=CANCELADO)      │
  │                │                │                │
```

---

## Idempotência

Todos os consumers de eventos RabbitMQ devem ser **idempotentes**.

**Estratégia:**
- Verificar estado atual antes de processar
- Usar `pedidoId` como chave de deduplicação
- Exemplo:

```java
@RabbitListener(queues = "pedidos.pagamento-aprovado")
public void onPagamentoAprovado(PagamentoAprovadoEvent evento) {
    Pedido pedido = pedidoRepository.findById(evento.getPedidoId());

    // Idempotência: só processa se ainda não foi processado
    if (pedido.getStatus() == StatusPedido.CRIADO) {
        pedido.setStatus(StatusPedido.REALIZADO);
        pedidoRepository.save(pedido);
    }
    // Se já foi processado, ignora silenciosamente
}
```

---

## Versionamento de APIs

**Padrão:** Sem versionamento explícito (v1 implícito).

Se necessário no futuro:
- Path-based: `/v2/pedidos/checkout`
- Header-based: `Accept: application/vnd.lanchonete.v2+json`

---

## Status Codes HTTP

| Code | Uso |
|------|-----|
| 200 OK | Sucesso em GET/PATCH |
| 201 Created | Sucesso em POST (criação) |
| 400 Bad Request | Validação falhou |
| 404 Not Found | Recurso não existe |
| 409 Conflict | Duplicação (ex: CPF já cadastrado) |
| 500 Internal Server Error | Erro inesperado |

---

## Headers HTTP

**Request:**
- `Content-Type: application/json`
- `Accept: application/json`

**Response:**
- `Content-Type: application/json`

---

## Segurança

**Atual:** Sem autenticação/autorização (ambiente acadêmico).

**Futuro (produção):**
- JWT entre cliente e API Gateway
- mTLS entre microserviços
- RabbitMQ com autenticação/SSL
