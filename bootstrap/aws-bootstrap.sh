#!/usr/bin/env bash
# =============================================================================
# Preparação única da conta AWS para as pipelines do ToDo App.
#
# Cria (ou atualiza, se já existirem):
#   1. Bucket S3 do Terraform State (versionado, criptografado, sem acesso público)
#   2. Bucket S3 dos backups do MongoDB (retenção automática por lifecycle)
#   3. Provedor OIDC do GitHub Actions (login na AWS sem chaves de acesso fixas)
#   4. Role IAM assumida pelas pipelines, restrita ao repositório informado
#
# Execute no AWS CloudShell (console da AWS, já autenticado):
#   bash bootstrap/aws-bootstrap.sh <dono/repositorio> [regiao]
#   ex.: bash bootstrap/aws-bootstrap.sh pedro/todo-app us-east-2
#
# Para remover tudo ao final do semestre (apaga state e backups!):
#   bash bootstrap/aws-bootstrap.sh <dono/repositorio> [regiao] --remover
# =============================================================================
set -euo pipefail

REPO="${1:?Informe o repositório GitHub no formato dono/repositorio}"
REGION="${2:-us-east-2}"
MODE="${3:-criar}"

PROJECT="todo-app"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-14}"
OIDC_HOST="token.actions.githubusercontent.com"

if [[ ! "$REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
  echo "Repositório inválido: '$REPO'. Use o formato dono/repositorio." >&2
  exit 1
fi

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
STATE_BUCKET="${PROJECT}-tfstate-${ACCOUNT_ID}"
BACKUP_BUCKET="${PROJECT}-backups-${ACCOUNT_ID}"
ROLE_NAME="${PROJECT}-github-actions"
OIDC_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_HOST}"
export AWS_DEFAULT_REGION="$REGION"

log() { printf '\n==> %s\n' "$*"; }

# ----------------------------------------------------------------------------
# Remoção (fim do semestre)
# ----------------------------------------------------------------------------
empty_bucket() {
  local bucket="$1"
  aws s3api head-bucket --bucket "$bucket" 2>/dev/null || return 0
  log "Esvaziando s3://${bucket} (todas as versões)"
  while true; do
    local batch
    batch="$(aws s3api list-object-versions --bucket "$bucket" --max-items 500 --output json |
      jq '{Objects: ([.Versions[]?, .DeleteMarkers[]?] | map({Key, VersionId})), Quiet: true}')"
    if [ "$(echo "$batch" | jq '.Objects | length')" -eq 0 ]; then
      break
    fi
    aws s3api delete-objects --bucket "$bucket" --delete "$batch" >/dev/null
  done
  aws s3api delete-bucket --bucket "$bucket"
}

if [ "$MODE" = "--remover" ]; then
  echo "ATENÇÃO: isto apaga o Terraform State, TODOS os backups e o acesso das pipelines."
  echo "Destrua antes os ambientes pela pipeline (infra.yml, ação destroy)."
  read -r -p "Digite 'remover ${PROJECT}' para confirmar: " answer
  [ "$answer" = "remover ${PROJECT}" ] || { echo "Cancelado."; exit 1; }
  aws iam delete-role-policy --role-name "$ROLE_NAME" --policy-name "${PROJECT}-pipeline" 2>/dev/null || true
  aws iam delete-role --role-name "$ROLE_NAME" 2>/dev/null || true
  aws iam delete-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN" 2>/dev/null || true
  empty_bucket "$BACKUP_BUCKET"
  empty_bucket "$STATE_BUCKET"
  log "Recursos de bootstrap removidos."
  exit 0
fi

# ----------------------------------------------------------------------------
# Buckets S3
# ----------------------------------------------------------------------------
create_bucket() {
  local bucket="$1"
  if aws s3api head-bucket --bucket "$bucket" 2>/dev/null; then
    echo "Bucket s3://${bucket} já existe"
  elif [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$bucket" >/dev/null
    echo "Bucket s3://${bucket} criado"
  else
    aws s3api create-bucket --bucket "$bucket" \
      --create-bucket-configuration "LocationConstraint=${REGION}" >/dev/null
    echo "Bucket s3://${bucket} criado"
  fi

  aws s3api put-public-access-block --bucket "$bucket" --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
  aws s3api put-bucket-encryption --bucket "$bucket" --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}'
  aws s3api put-bucket-versioning --bucket "$bucket" --versioning-configuration Status=Enabled
  aws s3api put-bucket-policy --bucket "$bucket" --policy "$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "SomenteTLS",
    "Effect": "Deny",
    "Principal": "*",
    "Action": "s3:*",
    "Resource": ["arn:aws:s3:::${bucket}", "arn:aws:s3:::${bucket}/*"],
    "Condition": {"Bool": {"aws:SecureTransport": "false"}}
  }]
}
EOF
)"
}

log "Bucket do Terraform State"
create_bucket "$STATE_BUCKET"
aws s3api put-bucket-lifecycle-configuration --bucket "$STATE_BUCKET" --lifecycle-configuration '{
  "Rules": [{
    "ID": "versoes-antigas-do-state",
    "Status": "Enabled",
    "Filter": {},
    "NoncurrentVersionExpiration": {"NoncurrentDays": 90}
  }]
}'

log "Bucket de backups do MongoDB (retenção de ${BACKUP_RETENTION_DAYS} dias)"
create_bucket "$BACKUP_BUCKET"
aws s3api put-bucket-lifecycle-configuration --bucket "$BACKUP_BUCKET" --lifecycle-configuration "{
  \"Rules\": [{
    \"ID\": \"retencao-backups\",
    \"Status\": \"Enabled\",
    \"Filter\": {},
    \"Expiration\": {\"Days\": ${BACKUP_RETENTION_DAYS}},
    \"NoncurrentVersionExpiration\": {\"NoncurrentDays\": 7},
    \"AbortIncompleteMultipartUpload\": {\"DaysAfterInitiation\": 1}
  }]
}"

# ----------------------------------------------------------------------------
# OIDC do GitHub Actions
# ----------------------------------------------------------------------------
log "Provedor OIDC do GitHub Actions"
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN" >/dev/null 2>&1; then
  echo "Provedor OIDC já existe"
else
  aws iam create-open-id-connect-provider \
    --url "https://${OIDC_HOST}" \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 1c58a3a8518e8759bf075b76b750d4f2df264fcd >/dev/null
  echo "Provedor OIDC criado"
fi

# ----------------------------------------------------------------------------
# Role das pipelines (somente o repositório informado pode assumi-la)
# ----------------------------------------------------------------------------
log "Role IAM ${ROLE_NAME} (repositório ${REPO})"
TRUST_POLICY="$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Federated": "${OIDC_ARN}"},
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {"${OIDC_HOST}:aud": "sts.amazonaws.com"},
      "StringLike": {"${OIDC_HOST}:sub": "repo:${REPO}:*"}
    }
  }]
}
EOF
)"

# Permissões mínimas para o que a pipeline gerencia: rede e VMs (EC2) na região
# escolhida, o state, a leitura/limpeza dos backups e as roles das VMs
# (prefixo todo-app-ec2-*, sem acesso à própria role da pipeline).
PIPELINE_POLICY="$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "RedeEVMs",
      "Effect": "Allow",
      "Action": "ec2:*",
      "Resource": "*",
      "Condition": {"StringEquals": {"aws:RequestedRegion": "${REGION}"}}
    },
    {
      "Sid": "TerraformStateBucket",
      "Effect": "Allow",
      "Action": ["s3:ListBucket", "s3:GetBucketLocation", "s3:GetBucketVersioning"],
      "Resource": "arn:aws:s3:::${STATE_BUCKET}"
    },
    {
      "Sid": "TerraformStateObjetos",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::${STATE_BUCKET}/*"
    },
    {
      "Sid": "BackupsLeituraELimpeza",
      "Effect": "Allow",
      "Action": ["s3:ListBucket", "s3:GetBucketLocation", "s3:GetObject", "s3:DeleteObject"],
      "Resource": ["arn:aws:s3:::${BACKUP_BUCKET}", "arn:aws:s3:::${BACKUP_BUCKET}/*"]
    },
    {
      "Sid": "RolesDasVMs",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:UpdateRole",
        "iam:UpdateAssumeRolePolicy", "iam:TagRole", "iam:UntagRole", "iam:ListRoleTags",
        "iam:PutRolePolicy", "iam:GetRolePolicy", "iam:DeleteRolePolicy",
        "iam:ListRolePolicies", "iam:ListAttachedRolePolicies",
        "iam:ListInstanceProfilesForRole", "iam:PassRole"
      ],
      "Resource": "arn:aws:iam::${ACCOUNT_ID}:role/${PROJECT}-ec2-*"
    },
    {
      "Sid": "InstanceProfilesDasVMs",
      "Effect": "Allow",
      "Action": [
        "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile", "iam:GetInstanceProfile",
        "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile",
        "iam:TagInstanceProfile", "iam:UntagInstanceProfile", "iam:ListInstanceProfileTags"
      ],
      "Resource": "arn:aws:iam::${ACCOUNT_ID}:instance-profile/${PROJECT}-ec2-*"
    }
  ]
}
EOF
)"

if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  aws iam update-assume-role-policy --role-name "$ROLE_NAME" --policy-document "$TRUST_POLICY"
  echo "Role já existia: política de confiança atualizada"
else
  aws iam create-role --role-name "$ROLE_NAME" \
    --description "Pipelines GitHub Actions do ToDo App (${REPO})" \
    --assume-role-policy-document "$TRUST_POLICY" \
    --max-session-duration 3600 >/dev/null
  echo "Role criada"
fi
aws iam put-role-policy --role-name "$ROLE_NAME" --policy-name "${PROJECT}-pipeline" \
  --policy-document "$PIPELINE_POLICY"

ROLE_ARN="$(aws iam get-role --role-name "$ROLE_NAME" --query Role.Arn --output text)"

cat <<EOF

==============================================================================
 Bootstrap concluído. Cadastre no GitHub (Settings > Secrets and variables >
 Actions > aba Variables) as variáveis do repositório:

   AWS_ROLE_ARN = ${ROLE_ARN}
   AWS_REGION   = ${REGION}

 Ou com a GitHub CLI:
   gh variable set AWS_ROLE_ARN --body "${ROLE_ARN}" --repo ${REPO}
   gh variable set AWS_REGION   --body "${REGION}" --repo ${REPO}

 Buckets: s3://${STATE_BUCKET} (state) e s3://${BACKUP_BUCKET} (backups)
==============================================================================
EOF
