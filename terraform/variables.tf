variable "project" {
  description = "Nome do projeto, usado como prefixo dos recursos."
  type        = string
  default     = "todo-app"
}

variable "environment" {
  description = "Ambiente de destino."
  type        = string

  validation {
    condition     = contains(["dev", "homolog", "prod"], var.environment)
    error_message = "O ambiente deve ser dev, homolog ou prod."
  }
}

variable "aws_region" {
  description = "Região da AWS."
  type        = string
  default     = "us-east-2"
}

variable "availability_zone" {
  description = "Zona de disponibilidade das VMs e do volume do banco. Vazio = primeira zona disponível da região."
  type        = string
  default     = ""
}

variable "instance_name" {
  description = "Nome base das máquinas virtuais (gera <nome>-app-<ambiente> e <nome>-db-<ambiente>)."
  type        = string
  default     = "vm-pm04"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.instance_name))
    error_message = "Use de 3 a 32 caracteres: letras minúsculas, números e hífen."
  }
}

variable "app_instance_type" {
  description = "Tipo da VM da aplicação (Caddy + Nginx/React + API)."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t3.small", "c7i-flex.large", "m7i-flex.large"], var.app_instance_type)
    error_message = "Use um tipo x86 elegível ao plano gratuito: t3.micro, t3.small, c7i-flex.large ou m7i-flex.large."
  }
}

variable "db_instance_type" {
  description = "Tipo da VM exclusiva do MongoDB."
  type        = string
  default     = "t3.small"

  validation {
    condition     = contains(["t3.micro", "t3.small", "c7i-flex.large", "m7i-flex.large"], var.db_instance_type)
    error_message = "Use um tipo x86 elegível ao plano gratuito: t3.micro, t3.small, c7i-flex.large ou m7i-flex.large."
  }
}

variable "app_root_volume_size" {
  description = "Disco do sistema da VM da aplicação (GB)."
  type        = number
  default     = 16
}

variable "db_root_volume_size" {
  description = "Disco do sistema da VM do banco (GB)."
  type        = number
  default     = 12
}

variable "db_data_volume_size" {
  description = "Volume EBS persistente com os dados do MongoDB (GB). Só pode aumentar."
  type        = number
  default     = 10

  validation {
    condition     = var.db_data_volume_size >= 5 && var.db_data_volume_size <= 50
    error_message = "O volume de dados deve ter entre 5 e 50 GB."
  }
}

variable "vpc_cidr" {
  description = "Faixa de endereços da VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "app_subnet_cidr" {
  description = "Sub-rede da VM da aplicação."
  type        = string
  default     = "10.20.1.0/24"
}

variable "db_subnet_cidr" {
  description = "Sub-rede da VM do banco."
  type        = string
  default     = "10.20.2.0/24"
}

variable "admin_cidrs" {
  description = "Origens (CIDR) autorizadas a acessar a VM da aplicação por SSH. A pipeline libera o próprio IP apenas durante a execução."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for cidr in var.admin_cidrs : can(cidrhost(cidr, 0))])
    error_message = "Informe CIDRs válidos, por exemplo 203.0.113.10/32."
  }
}

variable "ssh_public_key" {
  description = "Chave pública SSH instalada nas VMs (a chave privada fica nos Secrets do GitHub)."
  type        = string
}

variable "domain_name" {
  description = "Domínio público da aplicação. Vazio = <ip-elastico>.sslip.io."
  type        = string
  default     = ""
}

variable "backup_bucket_name" {
  description = "Bucket S3 dos backups. Vazio = todo-app-backups-<conta> (criado pelo bootstrap)."
  type        = string
  default     = ""
}
