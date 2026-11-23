# Duas VMs (REQ-01): aplicação e MongoDB em servidores distintos.
# Alterar instance_type é uma atualização no local (stop/start), sem recriar a VM.
# CPU em modo "standard" nas instâncias t3: evita cobrança de créditos extras.

resource "aws_key_pair" "deployer" {
  key_name   = "${local.name_prefix}-deployer"
  public_key = trimspace(var.ssh_public_key)
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.app_instance_type
  subnet_id              = aws_subnet.app.id
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = aws_key_pair.deployer.key_name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.app_root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  dynamic "credit_specification" {
    for_each = startswith(var.app_instance_type, "t") ? [1] : []

    content {
      cpu_credits = "standard"
    }
  }

  tags = {
    Name = local.app_vm_name
    Role = "aplicacao"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# IP fixo: o endereço público (e o nome <ip>.sslip.io) não muda quando a VM
# é parada, redimensionada ou reiniciada.
resource "aws_eip" "app" {
  domain = "vpc"

  tags = {
    Name = "${local.name_prefix}-eip-app"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_eip_association" "app" {
  allocation_id = aws_eip.app.id
  instance_id   = aws_instance.app.id
}

resource "aws_instance" "db" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.db_instance_type
  subnet_id              = aws_subnet.db.id
  vpc_security_group_ids = [aws_security_group.db.id]
  key_name               = aws_key_pair.deployer.key_name
  iam_instance_profile   = aws_iam_instance_profile.db.name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.db_root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  dynamic "credit_specification" {
    for_each = startswith(var.db_instance_type, "t") ? [1] : []

    content {
      cpu_credits = "standard"
    }
  }

  tags = {
    Name = local.db_vm_name
    Role = "banco"
  }

  lifecycle {
    ignore_changes = [ami]
  }

  depends_on = [aws_route_table_association.db]
}
