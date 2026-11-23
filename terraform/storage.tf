# Armazenamento persistente do MongoDB (REQ-04): volume EBS separado da VM.
# Recriar ou redimensionar a VM do banco não apaga os dados; o Ansible formata
# o volume apenas na primeira vez e o monta em /srv/mongo-data.
# Os backups (mongodump) vão para o bucket S3 criado pelo bootstrap.

resource "aws_ebs_volume" "mongo_data" {
  availability_zone = local.availability_zone
  size              = var.db_data_volume_size
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "${local.name_prefix}-mongo-data"
  }
}

resource "aws_volume_attachment" "mongo_data" {
  device_name                    = "/dev/sdf"
  volume_id                      = aws_ebs_volume.mongo_data.id
  instance_id                    = aws_instance.db.id
  stop_instance_before_detaching = true
}
