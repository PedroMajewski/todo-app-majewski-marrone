#!/usr/bin/env bash
# Testes de fumaça executados de FORA da AWS (runner do GitHub), como um
# visitante: HTTPS, saúde da API com o banco, fluxo completo de uma tarefa
# (ACE-04) e isolamento da rede (ACE-03). A tarefa de teste é removida no fim.
# Uso: smoke-test.sh <url> [ip-publico-vm-banco] [ip-publico-vm-app]
set -euo pipefail

URL="${1:?URL da aplicação, ex.: https://1-2-3-4.sslip.io}"
DB_PUBLIC_IP="${2:-}"
APP_PUBLIC_IP="${3:-}"
HOST="${URL#https://}"
HOST="${HOST%%/*}"
SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/null}"

{
  echo "### Testes de fumaça — ${URL}"
  echo ""
  echo "| Resultado | Verificação |"
  echo "|:---:|---|"
} >> "$SUMMARY"
pass() { echo "OK    $*"; echo "| ✅ | $* |" >> "$SUMMARY"; }
fail() { echo "FALHA $*" >&2; echo "| ❌ | $* |" >> "$SUMMARY"; exit 1; }

# 1) HTTPS (aguarda a emissão do certificado na primeira execução)
code="000"
for _ in $(seq 1 40); do
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "${URL}/" || true)"
  [ "$code" = "200" ] && break
  sleep 6
done
[ "$code" = "200" ] || fail "Página inicial via HTTPS (HTTP ${code})"
ISSUER="$(echo | openssl s_client -connect "${HOST}:443" -servername "$HOST" 2>/dev/null | openssl x509 -noout -issuer 2>/dev/null | sed 's/^issuer=//')"
pass "Página inicial via HTTPS com certificado válido (emissor: ${ISSUER:-n/d})"

code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "http://${HOST}/" || true)"
[[ "$code" =~ ^30[178]$ ]] || fail "Redirecionamento de HTTP para HTTPS (HTTP ${code})"
pass "HTTP redireciona para HTTPS (HTTP ${code})"

# 2) Saúde: API no ar e conectada ao MongoDB pela rede privada
HEALTH="$(curl -fsS --max-time 10 "${URL}/health")" || fail "Rota /health"
echo "$HEALTH" | jq -e '.status == "ok" and .database == "up"' >/dev/null || fail "API conectada ao MongoDB (${HEALTH})"
pass "API saudável e conectada ao MongoDB (versão $(echo "$HEALTH" | jq -r .version))"

# 3) Fluxo funcional completo pelo mesmo endereço público
TEXT="Teste automatizado ${GITHUB_RUN_ID:-local}-$(date +%s)"
CREATED="$(curl -fsS --max-time 10 -X POST -H 'Content-Type: application/json' \
  -d "$(jq -n --arg t "$TEXT" '{text: $t}')" "${URL}/todos")" || fail "Cadastrar tarefa (POST /todos)"
ID="$(echo "$CREATED" | jq -r '._id')"
echo "$CREATED" | jq -e '.completed == false' >/dev/null || fail "Tarefa criada como pendente"
curl -fsS --max-time 10 "${URL}/todos" | jq -e --arg id "$ID" 'any(.[]; ._id == $id)' >/dev/null || fail "Listar tarefas (GET /todos)"
curl -fsS --max-time 10 -X PATCH "${URL}/todos/${ID}" | jq -e '.completed == true' >/dev/null || fail "Concluir tarefa (PATCH)"
curl -fsS --max-time 10 -X PATCH "${URL}/todos/${ID}" | jq -e '.completed == false' >/dev/null || fail "Reabrir tarefa (PATCH)"
curl -fsS --max-time 10 -X DELETE "${URL}/todos/${ID}" | jq -e '.message' >/dev/null || fail "Excluir tarefa (DELETE)"
curl -fsS --max-time 10 "${URL}/todos" | jq -e --arg id "$ID" 'all(.[]; ._id != $id)' >/dev/null || fail "Conferir exclusão após recarregar"
pass "Cadastrar, listar, concluir, reabrir e excluir uma tarefa pela URL pública"

# 4) Isolamento: nada além de 80/443 acessível pela internet
if [ -n "$DB_PUBLIC_IP" ]; then
  for port in 27017 22; do
    if nc -z -w 5 "$DB_PUBLIC_IP" "$port" 2>/dev/null; then
      fail "Porta ${port} da VM do banco acessível pela internet (${DB_PUBLIC_IP})"
    fi
  done
  pass "VM do banco: MongoDB (27017) e SSH inacessíveis pela internet (${DB_PUBLIC_IP})"
fi
if [ -n "$APP_PUBLIC_IP" ]; then
  for port in 27017 5000; do
    if nc -z -w 5 "$APP_PUBLIC_IP" "$port" 2>/dev/null; then
      fail "Porta ${port} da VM da aplicação acessível pela internet"
    fi
  done
  pass "VM da aplicação: API (5000) e MongoDB (27017) não expostos; entrada apenas por 80/443"
fi
echo "" >> "$SUMMARY"
