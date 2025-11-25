-- ============================================================================
-- Schema do Sistema de Autoatendimento - Lanchonete
-- Banco: MySQL 8.0+
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Tabela: cliente
-- Descrição: Armazena dados dos clientes cadastrados
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cliente (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    cpf VARCHAR(11) NOT NULL UNIQUE COMMENT 'CPF do cliente (apenas números)',
    nome VARCHAR(255) NOT NULL COMMENT 'Nome completo do cliente',
    email VARCHAR(255) NOT NULL COMMENT 'Email de contato'
) COMMENT='Cadastro de clientes';

-- ----------------------------------------------------------------------------
-- Tabela: produto
-- Descrição: Catálogo de produtos disponíveis para venda
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS produto (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(255) NOT NULL UNIQUE COMMENT 'Nome do produto',
    descricao VARCHAR(255) COMMENT 'Descrição detalhada do produto',
    preco DECIMAL(10,2) NOT NULL COMMENT 'Preço unitário do produto',
    categoria VARCHAR(50) NOT NULL COMMENT 'Categoria: LANCHE, ACOMPANHAMENTO, BEBIDA, SOBREMESA'
) COMMENT='Catálogo de produtos';

-- Índice para otimizar consultas de produtos por categoria
CREATE INDEX idx_produto_categoria ON produto(categoria);

-- ----------------------------------------------------------------------------
-- Tabela: pedido
-- Descrição: Pedidos realizados pelos clientes
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS pedido (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    cliente_id BIGINT COMMENT 'Referência ao cliente (NULL para pedidos anônimos)',
    status VARCHAR(50) NOT NULL COMMENT 'Status: RECEBIDO, EM_PREPARACAO, PRONTO, FINALIZADO',
    status_pagamento VARCHAR(50) NOT NULL DEFAULT 'PENDENTE' COMMENT 'Status: PENDENTE, APROVADO, REJEITADO',
    data_criacao DATETIME NOT NULL COMMENT 'Data e hora de criação do pedido',
    valor_total DECIMAL(10,2) NOT NULL COMMENT 'Valor total do pedido',
    FOREIGN KEY (cliente_id) REFERENCES cliente(id)
) COMMENT='Pedidos realizados';

-- Índice para otimizar consultas de pedidos por status
CREATE INDEX idx_pedido_status ON pedido(status);

-- Índice para otimizar consultas por status de pagamento
CREATE INDEX idx_pedido_status_pagamento ON pedido(status_pagamento);

-- Índice para otimizar ordenação e busca por data
CREATE INDEX idx_pedido_data_criacao ON pedido(data_criacao);

-- ----------------------------------------------------------------------------
-- Tabela: item_pedido
-- Descrição: Itens que compõem cada pedido (tabela associativa)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS item_pedido (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    pedido_id BIGINT NOT NULL COMMENT 'Referência ao pedido',
    produto_id BIGINT NOT NULL COMMENT 'Referência ao produto',
    quantidade INTEGER NOT NULL COMMENT 'Quantidade do produto no pedido',
    valor_unitario DECIMAL(10,2) NOT NULL COMMENT 'Valor unitário no momento do pedido',
    valor_total DECIMAL(10,2) NOT NULL COMMENT 'Valor total do item (quantidade * valor_unitario)',
    FOREIGN KEY (pedido_id) REFERENCES pedido(id),
    FOREIGN KEY (produto_id) REFERENCES produto(id)
) COMMENT='Itens dos pedidos';

-- Índice para otimizar JOIN entre pedido e item_pedido
CREATE INDEX idx_item_pedido_pedido_id ON item_pedido(pedido_id);

-- Índice para otimizar consultas de produtos mais vendidos
CREATE INDEX idx_item_pedido_produto_id ON item_pedido(produto_id);