# Regras de acesso. As regras são recursos separados para que a pipeline possa
# liberar temporariamente o SSH ao IP do runner (via AWS CLI) sem gerar
# diferenças no Terraform. Descrições em ASCII (exigência da AWS).

# ----------------------------------------------------------------------------
# VM da aplicação
# ----------------------------------------------------------------------------
resource "aws_security_group" "app" {
  name        = "${local.name_prefix}-app"
  description = "VM da aplicacao: HTTP e HTTPS publicos, SSH somente de origens autorizadas"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-sg-app"
  }
}

resource "aws_vpc_security_group_ingress_rule" "app_http" {
  security_group_id = aws_security_group.app.id
  description       = "HTTP publico (redirecionamento e validacao do certificado)"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "app_https" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS publico (interface e API)"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "app_ssh_admin" {
  for_each = toset(var.admin_cidrs)

  security_group_id = aws_security_group.app.id
  description       = "SSH de administracao autorizado"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  description       = "Saida liberada (pacotes, imagens, certificados)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ----------------------------------------------------------------------------
# VM do banco: nenhuma regra aceita origem da internet
# ----------------------------------------------------------------------------
resource "aws_security_group" "db" {
  name        = "${local.name_prefix}-db"
  description = "VM do MongoDB: porta 27017 e SSH somente a partir da VM da aplicacao"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-sg-db"
  }
}

resource "aws_vpc_security_group_ingress_rule" "db_mongo_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "MongoDB somente para a API na VM da aplicacao"
  ip_protocol                  = "tcp"
  from_port                    = 27017
  to_port                      = 27017
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_ingress_rule" "db_ssh_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "SSH somente via VM da aplicacao (bastion)"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_egress_rule" "db_all" {
  security_group_id = aws_security_group.db.id
  description       = "Saida liberada (pacotes, imagens, envio de backups)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
