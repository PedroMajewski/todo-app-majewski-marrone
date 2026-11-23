# Identidade da VM do banco: envia e lê backups somente na pasta do próprio
# ambiente no bucket S3. Nenhuma chave de acesso é gravada na máquina
# (credenciais temporárias via metadados da instância, IMDSv2).

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "db_backup" {
  statement {
    sid       = "GravarELerBackupsDoAmbiente"
    actions   = ["s3:PutObject", "s3:GetObject"]
    resources = ["arn:aws:s3:::${local.backup_bucket}/${local.backup_prefix}/*"]
  }

  statement {
    sid       = "ListarBackupsDoAmbiente"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${local.backup_bucket}"]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${local.backup_prefix}/*"]
    }
  }
}

resource "aws_iam_role" "db" {
  name               = "${var.project}-ec2-db-${var.environment}"
  description        = "VM do MongoDB (${var.environment}): envio e leitura dos backups no S3"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy" "db_backup" {
  name   = "mongodb-backup-s3"
  role   = aws_iam_role.db.id
  policy = data.aws_iam_policy_document.db_backup.json
}

resource "aws_iam_instance_profile" "db" {
  name = "${var.project}-ec2-db-${var.environment}"
  role = aws_iam_role.db.name
}
