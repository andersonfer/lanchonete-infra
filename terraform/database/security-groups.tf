# Busca a VPC padrão
data "aws_vpc" "padrao" {
  default = true
}

# Busca todas as subnets da VPC
data "aws_subnets" "disponiveis" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.padrao.id]
  }
}

# Security Group para MySQL (3 instâncias RDS)
resource "aws_security_group" "mysql" {
  name_prefix = "${local.prefix}-mysql-"
  description = "Security group para RDS MySQL (clientes, pedidos, cozinha)"
  vpc_id      = data.aws_vpc.padrao.id

  # Permite conexões MySQL de dentro da VPC
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.padrao.cidr_block]
    description = "MySQL access from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.prefix}-mysql-sg"
    }
  )
}

# Subnet Group para os bancos RDS MySQL
resource "aws_db_subnet_group" "principal" {
  name       = "${local.prefix}-db-subnet-group"
  subnet_ids = data.aws_subnets.disponiveis.ids

  tags = merge(
    local.common_tags,
    {
      Name = "${local.prefix}-db-subnet-group"
    }
  )
}
