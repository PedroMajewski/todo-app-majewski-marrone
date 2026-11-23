#!/usr/bin/env bash
# Resume um plano do Terraform (tfplan) no resumo da execução do GitHub Actions
# e grava has_changes=true|false em GITHUB_OUTPUT.
# Uso: tf-plan-summary.sh <arquivo-tfplan> <arquivo-texto-do-plano>
set -euo pipefail

PLAN_FILE="${1:?arquivo tfplan}"
PLAN_TEXT="${2:?arquivo com a saída do plan}"
SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/stdout}"

JSON="$(terraform -chdir=terraform show -json "$PLAN_FILE")"
count() { echo "$JSON" | jq "[.resource_changes[]? | select(.change.actions == $1)] | length"; }
CREATE="$(count '["create"]')"
UPDATE="$(count '["update"]')"
DELETE="$(count '["delete"]')"
REPLACE="$(echo "$JSON" | jq '[.resource_changes[]? | select((.change.actions | length) == 2)] | length')"
TOTAL=$((CREATE + UPDATE + DELETE + REPLACE))

{
  echo "### Terraform plan"
  echo ""
  echo "| Criar | Alterar no local | Recriar | Remover |"
  echo "|:---:|:---:|:---:|:---:|"
  echo "| ${CREATE} | ${UPDATE} | ${REPLACE} | ${DELETE} |"
  echo ""
  if [ "$TOTAL" -eq 0 ]; then
    echo "**Nenhuma alteração de infraestrutura** (o ambiente já está no estado desejado)."
  else
    echo "Recursos afetados:"
    echo ""
    echo "$JSON" | jq -r '.resource_changes[]? | select(.change.actions != ["no-op"] and .change.actions != ["read"])
      | "- `\(.address)`: \(.change.actions | join(" + "))"'
  fi
  echo ""
  echo "<details><summary>Saída completa do plan</summary>"
  echo ""
  echo '```'
  sed -n '/Terraform will perform\|No changes\|Terraform used the selected/,$p' "$PLAN_TEXT" | head -n 400
  echo '```'
  echo "</details>"
} >> "$SUMMARY"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  if [ "$TOTAL" -gt 0 ]; then echo "has_changes=true" >> "$GITHUB_OUTPUT"; else echo "has_changes=false" >> "$GITHUB_OUTPUT"; fi
fi
