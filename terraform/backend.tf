# Terraform State remoto no S3 (criado pelo bootstrap/aws-bootstrap.sh).
# Configuração parcial: bucket, key e region são informados pela pipeline em
# "terraform init -backend-config=...", com um arquivo de state por ambiente:
#   s3://todo-app-tfstate-<conta>/todo-app/<ambiente>/terraform.tfstate
# O bucket é versionado (recuperação de versões anteriores) e criptografado;
# use_lockfile cria um lock no próprio S3 e impede execuções simultâneas.
terraform {
  backend "s3" {
    encrypt      = true
    use_lockfile = true
  }
}
