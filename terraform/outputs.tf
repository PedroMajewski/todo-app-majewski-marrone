# Saídas usadas pela pipeline para gerar o inventário do Ansible, executar os
# testes de fumaça e registrar o inventário de recursos como evidência.

output "environment" {
  description = "Ambiente provisionado."
  value       = var.environment
}

output "app_url" {
  description = "Endereço público HTTPS da aplicação."
  value       = "https://${local.app_fqdn}"
}

output "app_fqdn" {
  description = "Nome DNS usado no certificado HTTPS."
  value       = local.app_fqdn
}

output "app_vm_name" {
  description = "Nome da VM da aplicação (usado no inventário do Ansible)."
  value       = local.app_vm_name
}

output "db_vm_name" {
  description = "Nome da VM do banco (usado no inventário do Ansible)."
  value       = local.db_vm_name
}

output "app_public_ip" {
  description = "IP elástico da VM da aplicação (única entrada pública)."
  value       = aws_eip.app.public_ip
}

output "app_private_ip" {
  description = "IP privado da VM da aplicação."
  value       = aws_instance.app.private_ip
}

output "app_instance_id" {
  description = "ID da VM da aplicação."
  value       = aws_instance.app.id
}

output "app_instance_type" {
  description = "Tipo da VM da aplicação."
  value       = aws_instance.app.instance_type
}

output "db_private_ip" {
  description = "IP privado do MongoDB (usado pela API)."
  value       = aws_instance.db.private_ip
}

output "db_public_ip" {
  description = "IP público da VM do banco, usado só para saída; nenhuma porta aceita conexões da internet."
  value       = aws_instance.db.public_ip
}

output "db_instance_id" {
  description = "ID da VM do banco."
  value       = aws_instance.db.id
}

output "db_instance_type" {
  description = "Tipo da VM do banco."
  value       = aws_instance.db.instance_type
}

output "mongo_data_volume_id" {
  description = "Volume EBS persistente do MongoDB."
  value       = aws_ebs_volume.mongo_data.id
}

output "app_security_group_id" {
  description = "Security group da VM da aplicação (a pipeline libera o SSH do runner temporariamente)."
  value       = aws_security_group.app.id
}

output "backup_bucket" {
  description = "Bucket S3 dos backups."
  value       = local.backup_bucket
}

output "backup_prefix" {
  description = "Pasta dos backups deste ambiente no bucket."
  value       = local.backup_prefix
}

output "availability_zone" {
  description = "Zona de disponibilidade das VMs."
  value       = local.availability_zone
}

output "aws_region" {
  description = "Região da AWS (usada pela AWS CLI na VM do banco)."
  value       = var.aws_region
}

output "ssh_user" {
  description = "Usuário SSH das VMs (Ubuntu)."
  value       = "ubuntu"
}
