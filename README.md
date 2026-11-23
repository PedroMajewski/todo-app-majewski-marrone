# ToDo App · Infraestrutura automatizada na AWS (PM-04)

**Integrantes:** Pedro Henrique Majewski e Gabriel Marrone de Lima
**Disciplina:** DevOps e Infraestrutura, 7º período (UniAmerica), Projeto Final PM-04

Aplicação de lista de tarefas (React + Nginx, API Node.js/Express e MongoDB) implantada na AWS para a **Feira de Profissões**. A infraestrutura é criada pelo **Terraform**, configurada e mantida pelo **Ansible**, e todas as mudanças passam por pipelines do **GitHub Actions** acionadas com parâmetros. Ninguém precisa entrar nos servidores.

```text
Visitantes ──HTTPS──► VM 1 · aplicação (IP elástico)            VM 2 · banco (exclusiva)
                      Caddy (TLS) → Nginx/React → API ─rede privada─► MongoDB autenticado
                                                     10.x:27017        volume EBS persistente
                                                                       backups → S3
```

| Documento | Conteúdo |
|---|---|
| [docs/arquitetura.md](docs/arquitetura.md) | Arquitetura, diagramas, decisões e justificativas, requisitos atendidos, limitações e premissas |
| [docs/custos.md](docs/custos.md) | Estimativa mensal e do período da feira, com fontes |
| [docs/manual-operacao.md](docs/manual-operacao.md) | Manual dos alunos: preparar, iniciar, verificar, atualizar, logs, backup, restaurar, preparar a demonstração e encerrar |
| [docs/validacao.md](docs/validacao.md) | Roteiro dos cenários de teste do PM-04 e dos critérios de aceite (ACE-01 a ACE-10), com as evidências |
| [docs/escopo.md](docs/escopo.md) | Documento de demanda (escopo do cliente) |

## Estrutura do repositório

```text
.github/
  workflows/
    ci.yml          testes, build, terraform fmt/validate, ansible-lint, actionlint
    release.yml     publica as imagens versionadas (vX.Y.Z) no GHCR e cria a release
    deploy-app.yml  implanta/retorna uma versão da aplicação (sem mexer na infra)
    infra.yml       PIPELINE PRINCIPAL: plan/apply/destroy → Terraform → Ansible → testes
    ops.yml         status, logs, restart, backup, restore-test, restore, reset-demo-list
  actions/infra-access/  acesso ao ambiente (OIDC, saídas do Terraform, inventário, SSH temporário)
  scripts/          init do state, resumo do plan, SSH temporário, testes de fumaça
bootstrap/aws-bootstrap.sh  preparação única da conta AWS (state, backups, OIDC)
terraform/          VPC, sub-redes, NACL, security groups, 2 VMs, IP elástico, EBS, IAM
  envs/             variáveis por ambiente (dev, homolog, prod)
ansible/
  playbook.yml      configuração completa (idempotente)
  ops.yml           rotinas operacionais
  inventory/        gerado a partir das saídas do Terraform
  group_vars/       variáveis (segredos lidos do ambiente da pipeline)
  roles/            common, os_updates, docker, mongodb, backup, containers
backend/ frontend/ banco-de-dados/  aplicação (adaptada para a nuvem)
docs/               documentação
evidencias/         capturas e registros das execuções
```

## Parâmetros da pipeline `Infraestrutura` (infra.yml)

Os parâmetros alteram de fato a infraestrutura (Terraform) ou a configuração (Ansible):

| Parâmetro | Exemplo | Efeito | Ferramenta |
|---|---|---|---|
| `environment` | dev / homolog / prod | Ambiente de destino (state, rede e segredos próprios) | Terraform + Ansible |
| `action` | plan / apply / destroy | Só planejar, criar/atualizar ou remover | Pipeline |
| `instance_name` | vm-pm04 | Nome das VMs (`vm-pm04-app-dev`, `vm-pm04-db-dev`) | Terraform |
| `app_instance_type` | t3.micro | Tamanho da VM da aplicação (troca sem recriar) | Terraform |
| `db_instance_type` | t3.small | Tamanho da VM do MongoDB (troca sem recriar) | Terraform |
| `db_volume_size` | 10 | Volume persistente do banco em GB (cresce sem perder dados) | Terraform + Ansible |
| `app_version` | v1.0.0 | Tag das imagens `todo-api` e `todo-frontend` (o *docker_tag* do PM-04) | Ansible |
| `mongo_version` | 8.0.38 | Tag da imagem `mongo` | Ansible |
| `update_os` | true / false | Aplica as atualizações do Ubuntu (e reinicia se preciso) | Ansible |
| `extra_packages` | git,tree,tmux | Pacotes adicionais nas VMs | Ansible |
| `pull_images` | true / false | Baixa de novo as imagens mesmo com a mesma tag | Ansible |
| `admin_cidrs` | 203.0.113.10/32 | IPs autorizados a SSH na VM da aplicação (vazio = fechado) | Terraform |
| `domain_name` | (vazio) | Domínio próprio; vazio = `<ip>.sslip.io` | Terraform + Ansible |
| `confirm_destroy` / `keep_backups` | dev / true | Confirmação e destino dos dados na remoção | Pipeline |

As imagens Docker não são escolhidas livremente (*docker_image*): a demanda define três serviços fixos. O que o parâmetro controla é a **versão** de cada um: `app_version` vale para a API e o frontend, `mongo_version` para o banco.

## Como usar (resumo)

O passo a passo completo está no [manual de operação](docs/manual-operacao.md).

1. **Preparação única:** rode `bootstrap/aws-bootstrap.sh <dono/repo>` no AWS CloudShell e cadastre no GitHub as variáveis `AWS_ROLE_ARN` e `AWS_REGION` e os secrets `SSH_PRIVATE_KEY`, `SSH_PUBLIC_KEY`, `MONGO_ROOT_PASSWORD`, `MONGO_APP_PASSWORD` e `MONGO_BACKUP_PASSWORD`.
2. **Publicar a aplicação:** crie a tag `v1.0.0`. O workflow *Release da aplicação* testa e publica as imagens.
3. **Cenário 1 (criação):** *Infraestrutura* com `action=apply`. A URL HTTPS aparece no resumo da execução.
4. **Cenário 2 (atualização):** rode de novo alterando, por exemplo, `app_instance_type=t3.small` (Terraform) e `extra_packages=git,tree` ou `update_os=true` (Ansible).
5. **Cenário 3 (idempotência):** repita com os mesmos parâmetros. O Terraform mostra *No changes* e o Ansible termina com `changed=0`.

## Executar localmente (Docker Compose)

Pré-requisitos: Git e Docker com Docker Compose (no Windows, Docker Desktop com containers Linux).

```bash
cp .env.example .env          # defina as senhas no arquivo .env
docker compose up --build -d
docker compose ps             # aguarde os três serviços ficarem "healthy"
```

Acesse **http://localhost**. A API responde no mesmo endereço (**http://localhost/todos**; saúde em **/health**). O MongoDB não é publicado no host e os dados ficam no volume `mongo-data`. `docker compose down` mantém os dados; `docker compose down -v` apaga.

Para desenvolver o frontend com recarga automática, rode a API (`cd backend && MONGO_URI=... npm start`) e depois `cd frontend && npm start`. O `proxy` do `package.json` encaminha `/todos` para a porta 5000.

## Adaptações feitas na aplicação (escopo, seção 5)

- O frontend chama `/todos` no mesmo endereço, sem `localhost:5000` (configurável com `REACT_APP_API_URL`).
- O Nginx encaminha `/todos`, `/todos/:id` e `/health` para a API, preservando métodos e caminhos.
- A API lê `MONGO_URI`, `PORT`, `CORS_ORIGIN` e `APP_VERSION` do ambiente, sem credenciais no código. O CORS fica restrito à origem da aplicação.
- A API ganhou a rota `/health`, que verifica a conexão com o MongoDB. Também passou a reconectar com espera progressiva e a encerrar de forma graciosa.
- O banco usa um usuário próprio da aplicação (readWrite só no `todo-app`) e um usuário de backup.
- Os dados de demonstração só são inseridos com a coleção vazia.
- O Compose não publica mais a porta do banco. Ele usa volume nomeado, credenciais no `.env` e espera os healthchecks antes de subir cada serviço.
- Os Dockerfiles usam Node 22 e `npm ci`, a API roda com usuário sem privilégios e as imagens têm versão fixa e HEALTHCHECK.

## Licença

Código original do ToDo App: ver [LICENSE](LICENSE).
