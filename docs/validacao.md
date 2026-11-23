# Roteiro de validação e evidências

Este roteiro cobre os **testes obrigatórios do PM-04** (cenários 1 a 3) e os **critérios de aceite do escopo** (ACE-01 a ACE-10). Para cada item há a execução que o comprova e o que registrar em `evidencias/` (captura do resumo da execução ou link da execução no GitHub Actions). Preencha a coluna **Execução** com o link de cada *run*.

## Testes obrigatórios do PM-04

### Cenário 1: criação inicial

| Passo | Execução | O que mostrar | Execução |
|---|---|---|---|
| 1.1 | `Infraestrutura` · `environment=dev`, `action=apply`, demais no padrão | *plan*: recursos a criar (VPC, sub-redes, NACL, SGs, 2 VMs, EIP, EBS, IAM) | |
| 1.2 | (mesma execução) | *apply*: inventário com a URL, IPs e tipos das VMs | |
| 1.3 | (mesma execução) | *configure*: Ansible instalando pacotes, Docker, MongoDB, backup e containers (`PLAY RECAP` com `changed>0`, `failed=0`) | |
| 1.4 | (mesma execução) | *smoke-test*: todas as verificações ✅ | |

### Cenário 2: atualização do ambiente

Execute de novo **alterando parâmetros**:

| Mudança | Parâmetro | Ferramenta | Resultado esperado |
|---|---|---|---|
| Infraestrutura | `app_instance_type=t3.small` | Terraform | *plan*: `1 a alterar no local` (aws_instance.app), **0 a recriar**; a URL e os dados continuam |
| Manutenção | `extra_packages=git,tree` e `update_os=true` | Ansible | Pacotes instalados, atualizações aplicadas (reinício se necessário), sem intervenção manual |
| Imagem Docker | `app_version=v1.1.0` (após publicar a release v1.1.0) | Ansible | Containers da API e do frontend atualizados; `/health` mostra `version: v1.1.0` |

Para ter uma v1.1.0, faça qualquer mudança simples (ex.: o título em `frontend/public/index.html`), commite e crie a tag `v1.1.0`.

### Cenário 3: reexecução sem alterações

Repita a execução do cenário 2 **com os mesmos parâmetros**:

- *plan*: **"Nenhuma alteração de infraestrutura"** (0/0/0/0) e o `apply` é pulado.
- *configure*: `PLAY RECAP` com **`changed=0`** nas duas VMs (idempotência do Ansible).
- *smoke-test*: ✅.

Para o `changed=0`, deixe `update_os=false` nesta repetição (ou repita depois de as atualizações terem sido aplicadas) e mantenha `pull_images=false`.

### Validação da demanda

Use a tabela de rastreabilidade de [arquitetura.md](arquitetura.md#1-análise-da-demanda) (requisito → recurso entregue) junto com as evidências abaixo.

## Critérios de aceite do escopo

| Critério | Como comprovar | Evidência | Execução |
|---|---|---|---|
| **ACE-01 Reprodução** | Ambiente criado do zero pela pipeline (Cenário 1); pré-requisitos no [manual](manual-operacao.md#0-preparação-única-feita-uma-vez-pela-equipe-de-infraestrutura) | Resumo do Cenário 1 | |
| **ACE-02 Duas VMs** | Inventário do *apply* (`app_instance_id`, `db_instance_id`) + `Operações status` (containers por VM: o MongoDB só na VM do banco) | Resumo + captura do console EC2 | |
| **ACE-03 Isolamento** | *smoke-test*: "VM do banco: MongoDB (27017) e SSH inacessíveis pela internet"; `/health` com `database: up` prova a conexão pela rede privada. Opcional: no seu computador, `nc -vz <db_public_ip> 27017` (deve falhar por tempo esgotado) | Resumo do smoke-test + captura do terminal | |
| **ACE-04 Aplicação pública** | No **celular**, abra a URL HTTPS: cadastre, liste, conclua, reabra e exclua uma tarefa; recarregue a página. O *smoke-test* repete esse fluxo automaticamente | Capturas/vídeo no celular | |
| **ACE-05 Persistência** | 1) cadastre a tarefa "persistência"; 2) `Operações restart target=all`; 3) `Operações restart target=db service=todo-mongo recreate=true`; 4) atualização da aplicação (Cenário 2); 5) após cada passo, a tarefa e o seu estado continuam na lista | Capturas + resumos das execuções | |
| **ACE-06 Automação** | Execuções do `Infraestrutura` e do `Release`/`Deploy da aplicação` com a versão identificada (`v1.0.0` → `v1.1.0`) e o rollback (`Deploy` com `v1.0.0`) | Links das execuções + página *Releases* | |
| **ACE-07 Recuperação** | `Operações backup` → `Operações list-backups` → `Operações restore-test backup_key=latest` | Saída com "OK: restauração conferida em ambiente isolado" | |
| **ACE-08 Operação** | `Operações status`, `logs`, `restart`; `Infraestrutura destroy` (em `dev`, no fim); credenciais ausentes do código e dos logs (busca por senha no log retorna `***`/vazio) | Resumos das execuções | |
| **ACE-09 Custos** | [custos.md](custos.md) | Documento | |
| **ACE-10 Transferência** | Os alunos executam com o manual: `status`, `logs`, `reset-demo-list` e um deploy | Registro do ensaio | |

## Comprovações rápidas (checklist do ensaio)

- [ ] `https://<url>` abre em outro dispositivo, com cadeado (certificado válido)
- [ ] `https://<url>/health` → `{"status":"ok","database":"up","version":"v1.x.x"}`
- [ ] Cenários 1, 2 e 3 executados e com os links preenchidos
- [ ] `restore-test` OK
- [ ] `reset-demo-list` executado antes da apresentação
- [ ] `destroy` validado em `dev` (e o ambiente recriado para a apresentação)
