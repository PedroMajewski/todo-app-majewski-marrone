# Manual de operação · ToDo App na AWS

Guia para a equipe e para os alunos operarem o ambiente **só pelas pipelines do GitHub Actions**, sem entrar nos servidores. Para cada rotina: quando usar, os parâmetros, o resultado esperado e o que fazer se falhar.

> Todas as execuções ficam em **GitHub → Actions**. Escolha o workflow à esquerda, clique em **Run workflow**, preencha os parâmetros e acompanhe. O **resumo** de cada execução (aba *Summary*) traz o plano do Terraform, o resultado do Ansible, os testes e o inventário: são as evidências.

---

## 0. Preparação única (feita uma vez pela equipe de infraestrutura)

### 0.1 Repositório

1. Crie um repositório **seu** no GitHub (ex.: `todo-app-pm04`), público para que o GitHub Actions e o GHCR sejam gratuitos.
2. Aponte o clone local para ele (o `origin` atual é o repositório do professor, que não recebe push):

   ```bash
   git remote rename origin upstream
   git remote add origin https://github.com/<seu-usuario>/todo-app-pm04.git
   git push -u origin main
   ```

### 0.2 Conta AWS (AWS CloudShell)

1. Entre no console da AWS e abra o **CloudShell** (ícone `>_` no topo), na região **US East (Ohio) us-east-2**.
2. Envie o arquivo `bootstrap/aws-bootstrap.sh` (menu *Actions → Upload file*) ou clone o repositório, e execute:

   ```bash
   bash aws-bootstrap.sh <seu-usuario>/todo-app-pm04 us-east-2
   ```

   O script cria o bucket do Terraform State, o bucket de backups, o login OIDC do GitHub e a role da pipeline. No final ele mostra o valor de `AWS_ROLE_ARN`. Use exatamente o mesmo nome do repositório, com maiúsculas e minúsculas iguais às do GitHub.
3. (Recomendado) Em **Billing → Budgets**, crie um orçamento de US$ 5 com alerta por e-mail.

### 0.3 Chave SSH e senhas

No seu computador (Git Bash, WSL ou Linux):

```bash
ssh-keygen -t ed25519 -N "" -C "pm04-deployer" -f pm04_deployer   # gera pm04_deployer e pm04_deployer.pub
openssl rand -hex 16    # rode 3 vezes: senhas root, app e backup (somente letras e números)
```

### 0.4 GitHub: variáveis, secrets e ambientes

Em **Settings → Secrets and variables → Actions**:

| Tipo | Nome | Valor |
|---|---|---|
| Variable | `AWS_ROLE_ARN` | ARN mostrado pelo bootstrap |
| Variable | `AWS_REGION` | `us-east-2` |
| Variable (opcional) | `ACME_EMAIL` | e-mail para avisos do Let's Encrypt |
| Secret | `SSH_PRIVATE_KEY` | conteúdo de `pm04_deployer` |
| Secret | `SSH_PUBLIC_KEY` | conteúdo de `pm04_deployer.pub` |

Em **Settings → Environments**, crie `dev` (e, se forem usados, `homolog` e `prod`) e, **em cada ambiente**, os secrets:

| Secret | Valor |
|---|---|
| `MONGO_ROOT_PASSWORD` | senha 1 (mínimo de 12 caracteres) |
| `MONGO_APP_PASSWORD` | senha 2 |
| `MONGO_BACKUP_PASSWORD` | senha 3 |

Para o ambiente `prod`, ative *Required reviewers*: o `apply` e o `destroy` passam a pedir aprovação de outro integrante.

Guarde a chave e as senhas em um gerenciador de senhas e apague os arquivos locais. **Nunca** coloque esses valores em arquivos do repositório.

### 0.5 Primeira versão da aplicação

```bash
git tag v1.0.0
git push origin v1.0.0
```

O workflow **Release da aplicação** roda os testes, publica `ghcr.io/<usuario>/todo-api:v1.0.0` e `todo-frontend:v1.0.0` e cria a release. Na primeira vez, abra **Packages** no seu perfil do GitHub e confira se os dois pacotes estão **públicos** (*Package settings → Change visibility*). A pipeline também consegue baixar pacotes privados com o token temporário.

---

## 1. Iniciar (criar o ambiente)

**Workflow:** `Infraestrutura` · **Parâmetros:** `environment=dev`, `action=apply` (os demais podem ficar no padrão).

**Resultado esperado (~10 a 15 min):**

- *plan*: tabela com cerca de 26 recursos a criar.
- *apply*: inventário com `app_url` (ex.: `https://3-91-10-20.sslip.io`), IPs e IDs.
- *configure*: `PLAY RECAP` sem `failed`.
- *smoke-test*: todas as verificações ✅ (HTTPS, CRUD completo, portas do banco fechadas).

Abra a `app_url` no celular para conferir.

Dica: rode antes com `action=plan` para ver o que será criado sem aplicar nada.

## 2. Verificar (saúde)

**Workflow:** `Operações` · `operation=status`, `target=all`.

**Resultado esperado:** para cada VM, os containers `Up (healthy)`, as versões implantadas, uso de disco e memória, a saúde da aplicação (`{"status":"ok","database":"up"...}`), o MongoDB (`ping=1 ... tarefas=N`) e o próximo backup agendado.

Verificação rápida pelo navegador: `https://<endereço>/health`.

## 3. Atualizar

| O que | Como |
|---|---|
| Nova versão da aplicação | Faça o commit, crie a tag (`git tag v1.1.0 && git push origin v1.1.0`) e depois rode **Deploy da aplicação** com `app_version=v1.1.0`. Ou rode *Release da aplicação* manualmente com `deploy_environment=dev` |
| Voltar à versão anterior | **Deploy da aplicação** com a versão anterior (lista em *Releases*). Se uma versão nova não ficar saudável, o Ansible já volta sozinho |
| Tamanho das VMs / volume | **Infraestrutura** `action=apply` com o novo `app_instance_type`, `db_instance_type` ou `db_volume_size`. A VM é parada e religada (1 a 2 min fora do ar); os dados e o IP são mantidos |
| Sistema operacional | **Infraestrutura** `action=apply`, `update_os=true`. Reinicia as VMs, uma por vez, se necessário |
| Pacotes | **Infraestrutura** `action=apply`, `extra_packages=git,tree` |
| Versão do MongoDB | **Infraestrutura** `action=apply`, `mongo_version=8.0.38` (patch da mesma série). Um backup é feito antes, automaticamente |
| Domínio próprio | Crie um registro DNS `A` apontando para o IP elástico (`app_public_ip`) e rode **Infraestrutura** com `domain_name=todo.seudominio.com.br` |

Os parâmetros da pipeline descrevem o estado desejado. Para manter uma alteração (ex.: `t3.small`), repita o mesmo valor nas próximas execuções. `app_version` e `mongo_version` vazios mantêm a versão em execução.

## 4. Consultar logs

**Workflow:** `Operações` · `operation=logs`, `target=app` ou `db`, `service=all` (ou `todo-api`, `todo-frontend`, `todo-caddy`, `todo-mongo`, `backup`) e `log_lines=200`.

## 5. Reiniciar serviços (sem apagar dados)

**Workflow:** `Operações` · `operation=restart`, `target` e `service` conforme o caso.

- `recreate=false`: `docker restart` dos containers escolhidos.
- `recreate=true`: recria os containers a partir da configuração e **mantém os volumes**. É a evidência de persistência do ACE-05.

**Reiniciar ≠ limpar a lista ≠ remover a infraestrutura.** As três rotinas são separadas de propósito.

## 6. Backups e restauração

| Rotina | Parâmetros | Resultado |
|---|---|---|
| Backup agora | `operation=backup` | `[backup] concluído: s3://.../todo-dev-<data>-manual.archive.gz (N tarefas...)` |
| Listar backups | `operation=list-backups` | Lista no resumo da execução |
| Testar restauração (isolada) | `operation=restore-test`, `backup_key=latest` (ou o nome do arquivo) | `[restore-test] OK: restauração conferida em ambiente isolado; banco da demonstração intacto` |
| Restaurar na demonstração | `operation=restore`, `backup_key=<arquivo>`, `confirm=<ambiente>` | Faz um backup de segurança e substitui as tarefas atuais pelas do backup |

Os backups automáticos rodam às **03:00 e 15:00** (horário de Brasília) e ficam **14 dias** no S3.

## 7. Preparar a demonstração (lista nova)

Antes de cada apresentação: **Operações** · `operation=reset-demo-list`, `confirm=dev`.

A rotina faz um backup de segurança, apaga as tarefas e reinsere as três tarefas de demonstração.

**Orientação aos visitantes:** a lista é compartilhada. Todos veem e podem alterar as mesmas tarefas, não há login e uma atualização em outro navegador só aparece ao recarregar a página. Use apenas textos de demonstração.

## 8. Encerrar (após a feira)

**Workflow:** `Infraestrutura` · `action=destroy`, `confirm_destroy=dev`, `keep_backups=true`.

**Resultado esperado:** backup final (`pre-destroy`), `terraform destroy` de todos os recursos e, no resumo, a lista do que **continua existindo** (backups e state no S3, com custo de centavos). Para recriar depois, basta rodar `action=apply` de novo.

Remoção total ao fim do semestre: no CloudShell, `bash aws-bootstrap.sh <repo> us-east-2 --remover`.

---

## 9. Diagnóstico de falhas comuns

| Sintoma | Causa provável | O que fazer |
|---|---|---|
| `plan` falha em *Credenciais AWS* / `Not authorized to perform sts:AssumeRoleWithWebIdentity` | `AWS_ROLE_ARN` errado ou repositório diferente do informado no bootstrap | Confira a variável; rode o bootstrap de novo com o nome exato `dono/repo` |
| `Defina o secret SSH_PUBLIC_KEY` | Secret ausente | Cadastre `SSH_PUBLIC_KEY` / `SSH_PRIVATE_KEY` |
| `apply` falha com `InvalidParameterCombination` / tipo não elegível | Tipo de VM fora do plano gratuito ou indisponível na zona | Use `t3.micro` / `t3.small` |
| Ansible: `Defina os secrets MONGO_...` | Secrets não cadastrados **no ambiente** (`dev`) | Settings → Environments → dev → secrets |
| Ansible: `Nenhuma versão da aplicação para implantar` | Nenhuma release publicada | Crie a tag `v1.0.0` (item 0.5) ou informe `app_version` |
| Ansible falha ao baixar imagem (`denied` / `not found`) | Tag inexistente no GHCR ou pacote privado sem acesso | Confira em *Packages*; deixe os pacotes públicos |
| Porta 22 não respondeu | VM ainda inicializando ou recriada | Rode de novo; se repetir, veja o console EC2 (estado da instância) |
| `smoke-test` falha em HTTPS | Certificado ainda sendo emitido ou DNS do `sslip.io` indisponível | `Operações → logs service=todo-caddy`; rode `Operações → status` em alguns minutos |
| `/health` responde `database: down` | MongoDB parado ou senha da aplicação divergente | `Operações → logs target=db`; `Operações → restart target=db`; reaplicar com `Infraestrutura apply` (recria o usuário) |
| Página abre mas não carrega tarefas | API fora do ar | `Operações → status`; `logs service=todo-api`; `restart service=todo-api` |
| `Saved plan is stale` | Outra execução alterou o ambiente entre o plan e o apply | Rode a pipeline novamente |
| Execução fica "aguardando" | Outra execução no mesmo ambiente (fila) ou aprovação pendente (`prod`) | Aguarde ou aprove em *Review deployments* |
| Recuperar o Terraform State | State corrompido ou apagado | Console S3 → bucket `todo-app-tfstate-<conta>` → `todo-app/<amb>/terraform.tfstate` → *Versões* → restaure a anterior |
