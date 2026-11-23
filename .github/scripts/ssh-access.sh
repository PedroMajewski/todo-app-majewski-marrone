#!/usr/bin/env bash
# Libera (open) ou revoga (close) o SSH da VM da aplicação SOMENTE para o IP do
# runner do GitHub Actions, durante a execução. Fora disso a porta 22 fica
# fechada (REQ-03). Regras esquecidas por execuções canceladas são removidas
# na próxima abertura.
# Uso: ssh-access.sh open <security-group-id> <ip-da-vm>
#      ssh-access.sh close <security-group-id>
set -euo pipefail

ACTION="${1:?open ou close}"
SG_ID="${2:?security group}"
HOST="${3:-}"
PREFIX="github-actions-run-"
TAG="${PREFIX}${GITHUB_RUN_ID:-local}-${GITHUB_RUN_ATTEMPT:-1}"

revoke_matching() {
  local query="$1" ids
  ids="$(aws ec2 describe-security-group-rules --filters "Name=group-id,Values=${SG_ID}" \
    --query "SecurityGroupRules[?IsEgress==\`false\` && ${query}].SecurityGroupRuleId" --output text)"
  for id in $ids; do
    [ "$id" = "None" ] && continue
    aws ec2 revoke-security-group-ingress --group-id "$SG_ID" --security-group-rule-ids "$id" >/dev/null
    echo "Regra SSH temporária removida: ${id}"
  done
}

case "$ACTION" in
  open)
    revoke_matching "starts_with(Description || '', '${PREFIX}')"
    IP="$(curl -fsS --max-time 10 https://checkip.amazonaws.com | tr -d '[:space:]')"
    aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --ip-permissions \
      "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=${IP}/32,Description=${TAG}}]" >/dev/null
    echo "SSH liberado temporariamente para ${IP}/32 (${TAG})"
    if [ -n "$HOST" ]; then
      for _ in $(seq 1 36); do
        if nc -z -w 5 "$HOST" 22; then
          echo "Porta 22 de ${HOST} respondendo"
          exit 0
        fi
        sleep 5
      done
      echo "A porta 22 de ${HOST} não respondeu" >&2
      exit 1
    fi
    ;;
  close)
    revoke_matching "Description == '${TAG}'"
    echo "SSH do runner revogado"
    ;;
  *)
    echo "Ação inválida: ${ACTION}" >&2
    exit 1
    ;;
esac
