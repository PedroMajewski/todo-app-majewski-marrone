# Rede própria do ambiente: VPC com duas sub-redes na mesma zona.
#  - app: VM da aplicação, com IP elástico (única entrada pública).
#  - db:  VM exclusiva do MongoDB. Recebe IP público apenas para SAÍDA
#         (atualizações e imagens), sem custo de NAT Gateway. A entrada a partir
#         da internet é bloqueada pelo security group e também pela NACL abaixo.

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

resource "aws_subnet" "app" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.app_subnet_cidr
  availability_zone       = local.availability_zone
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-subnet-app"
    Tier = "aplicacao"
  }
}

resource "aws_subnet" "db" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.db_subnet_cidr
  availability_zone       = local.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-subnet-db"
    Tier = "banco"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${local.name_prefix}-rt-public"
  }
}

resource "aws_route_table_association" "app" {
  subnet_id      = aws_subnet.app.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "db" {
  subnet_id      = aws_subnet.db.id
  route_table_id = aws_route_table.public.id
}

# Segunda camada de isolamento da sub-rede do banco (stateless):
#  100: tudo o que vem de dentro da VPC (API -> MongoDB, SSH via VM da aplicação)
#  110: bloqueia explicitamente a porta do MongoDB vinda de fora da VPC
#  120/130: respostas das conexões de saída (portas efêmeras)
resource "aws_network_acl" "db" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = [aws_subnet.db.id]

  ingress {
    rule_no    = 100
    action     = "allow"
    protocol   = "-1"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  ingress {
    rule_no    = 110
    action     = "deny"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 27017
    to_port    = 27017
  }

  ingress {
    rule_no    = 120
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  ingress {
    rule_no    = 130
    action     = "allow"
    protocol   = "udp"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  egress {
    rule_no    = 100
    action     = "allow"
    protocol   = "-1"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "${local.name_prefix}-nacl-db"
  }
}
