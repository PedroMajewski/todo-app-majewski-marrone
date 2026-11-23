data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# Ubuntu Server 24.04 LTS oficial da Canonical. Novas versões da imagem não
# recriam as VMs existentes (ignore_changes = [ami]); as atualizações do
# sistema operacional são aplicadas pelo Ansible (parâmetro update_os).
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  name_prefix       = "${var.project}-${var.environment}"
  availability_zone = var.availability_zone != "" ? var.availability_zone : sort(data.aws_availability_zones.available.names)[0]
  app_vm_name       = "${var.instance_name}-app-${var.environment}"
  db_vm_name        = "${var.instance_name}-db-${var.environment}"
  backup_bucket     = var.backup_bucket_name != "" ? var.backup_bucket_name : "${var.project}-backups-${data.aws_caller_identity.current.account_id}"
  backup_prefix     = var.environment
  app_fqdn          = var.domain_name != "" ? var.domain_name : "${replace(aws_eip.app.public_ip, ".", "-")}.sslip.io"
}
