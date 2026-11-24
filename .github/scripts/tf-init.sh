#!/usr/bin/env bash
# terraform init com o state remoto do ambiente (bucket criado pelo bootstrap).
# Uso: tf-init.sh <ambiente>
set -euo pipefail

ENVIRONMENT="${1:?Informe o ambiente (dev, homolog ou prod)}"
REGION="${AWS_REGION:-us-east-2}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="${TF_STATE_BUCKET:-todo-app-tfstate-${ACCOUNT_ID}}"

echo "State remoto: s3://${BUCKET}/todo-app/${ENVIRONMENT}/terraform.tfstate"
terraform -chdir=terraform init -input=false -reconfigure \
  -backend-config="bucket=${BUCKET}" \
  -backend-config="key=todo-app/${ENVIRONMENT}/terraform.tfstate" \
  -backend-config="region=${REGION}"
