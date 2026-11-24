# Estimativa de custos

**Provedor:** AWS · **Região:** us-east-2 (Ohio), com preços iguais aos da us-east-1 para os recursos usados · **Moeda:** dólar americano (US$)
**Data dos preços:** consultados em 23/11/2026 nas páginas oficiais listadas em [Fontes](#fontes) · **Mês de referência:** 730 horas

## 1. Recursos e preços unitários

| Recurso | Função / dimensionamento | Preço unitário | Quantidade | Custo mensal (24x7) |
|---|---|---|---|---|
| EC2 `t3.micro` (2 vCPU, 1 GiB) | VM da aplicação: Caddy, Nginx/React e API; a carga é leve e há 1 GiB de swap | US$ 0,0104/h | 730 h | **US$ 7,59** |
| EC2 `t3.small` (2 vCPU, 2 GiB) | VM exclusiva do MongoDB (cache do WiredTiger + sistema) | US$ 0,0208/h | 730 h | **US$ 15,18** |
| IPv4 público | IP elástico da aplicação + IP de saída da VM do banco | US$ 0,005/h por IP | 2 × 730 h | **US$ 7,30** |
| EBS gp3 | Discos do sistema (16 + 12 GB) + dados do MongoDB (10 GB) | US$ 0,08/GB-mês | 38 GB | **US$ 3,04** |
| S3 (state + backups) | State de poucos KB; backups compactados de poucos KB cada, 14 dias de retenção | US$ 0,023/GB-mês (Standard) | < 0,1 GB | **< US$ 0,01** |
| Transferência para a internet | Páginas e JSON da aplicação; a primeira emissão do certificado | 100 GB/mês gratuitos | < 5 GB | **US$ 0,00** |
| GitHub Actions | Runners padrão em repositório público | Gratuito | | **US$ 0,00** |
| GHCR (imagens) | Pacotes públicos | Gratuito | ~2 imagens × versões | **US$ 0,00** |
| DNS / certificado | `sslip.io` + Let's Encrypt | Gratuito | | **US$ 0,00** |
| **Total** | | | | **≈ US$ 33,11/mês** |

Custo por hora com o ambiente completo ligado: 0,0104 + 0,0208 + 2 × 0,005 + (38 × 0,08 / 730) ≈ **US$ 0,045/h** (≈ US$ 1,09 por dia).

As instâncias `t3` estão configuradas com CPU em modo *standard*, sem créditos extras cobrados (o modo *unlimited* cobraria um adicional por vCPU-hora). A troca para `t3.small` na VM da aplicação (Cenário 2 do PM-04) acrescenta US$ 0,0104/h enquanto estiver ativa.

## 2. Custo do período

As datas da feira ainda não foram informadas. Os cenários abaixo usam a premissa de [arquitetura.md](arquitetura.md#7-premissas-a-confirmar-com-a-organização-da-feira):

| Cenário | Horas ligado | Custo estimado |
|---|---|---|
| **A. Sob demanda (recomendado):** criar para gerar as evidências (~4 h) + apresentação do PM-04 (~4 h) + ensaio na véspera (~8 h) + dia da feira (~12 h) | ~28 h | **≈ US$ 1,27** |
| B. Ligado sem interrupção de 24/11 a 05/12/2026 (preparação + apresentação) | 288 h | ≈ US$ 13,06 |
| C. Ligado 24x7 por um mês inteiro | 730 h | ≈ US$ 33,11 |

O ambiente é reproduzível pela pipeline (cerca de 10 minutos para criar), então a recomendação é **destruir após cada uso** (cenário A). Os backups ficam guardados no S3.

## 3. Créditos e faixas gratuitas (separados do custo recorrente)

- **Plano gratuito da AWS (conta criada após 15/07/2025):** US$ 100 em créditos no cadastro, mais até US$ 100 por atividades, válidos por 6 meses ou até acabarem. Os tipos `t3.micro` e `t3.small` são elegíveis. **Em qualquer um dos cenários acima o custo efetivo é US$ 0,00**, pois tudo é abatido dos créditos.
- No plano gratuito não há cobrança acima dos créditos. A conta é encerrada quando os créditos acabam ou após 6 meses; para continuar depois disso, seria preciso migrar para o plano pago.
- Faixas sempre gratuitas usadas: 100 GB/mês de transferência para a internet; GitHub Actions em repositório público.

## 4. O que continua gerando custo após a feira

O `destroy` da pipeline remove as VMs, o IP elástico, os volumes EBS, a VPC e as regras. Continuam existindo:

| Item | Custo aproximado | Como remover |
|---|---|---|
| Backups do ambiente no S3 (`keep_backups=true`) | centavos por mês (KB a MB); expiram sozinhos em 14 dias | `infra.yml` com `keep_backups=false` ou aguardar a expiração |
| Terraform State no S3 (versões antigas por 90 dias) | < US$ 0,01/mês | `bootstrap/aws-bootstrap.sh <repo> <região> --remover` |
| Role OIDC e provedor OIDC (IAM) | gratuito | mesmo script `--remover` |
| Imagens no GHCR | gratuito em pacote público | apagar os pacotes no GitHub, se desejado |

**Atenção:** IP elástico parado sem uso é cobrado (US$ 0,005/h). Por isso o encerramento recomendado é o `destroy`, não apenas desligar as VMs.

## 5. Fatores de variação

- Preços sob demanda podem mudar. Os valores acima foram conferidos nas páginas oficiais na data indicada.
- Outra região (ex.: sa-east-1, São Paulo) tem preços maiores.
- Volume de visitantes muito acima da premissa aumentaria a transferência de dados (acima de 100 GB/mês) e poderia exigir VMs maiores.
- Repositório privado consumiria minutos do GitHub Actions da cota do plano.
- Alternativas descartadas pelo custo: NAT Gateway (US$ 0,045/h, ~US$ 33/mês, mais US$ 0,045/GB) e Load Balancer.

## Fontes

- Preços EC2 T3 (sob demanda, Linux): <https://aws.amazon.com/ec2/pricing/on-demand/> (selecione US East (Ohio)) e <https://aws.amazon.com/ec2/instance-types/t3/>; conferência para us-east-2: <https://www.doit.com/compute/spot/us-east-2/t3.small>
- Cobrança de IPv4 público (US$ 0,005/h por IP): <https://aws.amazon.com/blogs/aws/new-aws-public-ipv4-address-charge-public-ip-insights/>
- EBS gp3 (US$ 0,08/GB-mês): <https://aws.amazon.com/ebs/pricing/> e <https://aws.amazon.com/ebs/general-purpose/>
- Transferência de dados (100 GB/mês gratuitos): <https://aws.amazon.com/about-aws/global-infrastructure/global-network/faqs>
- NAT Gateway (US$ 0,045/h e por GB): <https://aws.amazon.com/vpc/pricing/>
- Plano gratuito da AWS e tipos elegíveis: <https://aws.amazon.com/free/> e <https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-free-tier-usage.html>
- GitHub Actions gratuito em repositórios públicos: <https://docs.github.com/en/billing/managing-billing-for-github-actions/about-billing-for-github-actions> e <https://github.blog/changelog/2026-01-01-reduced-pricing-for-github-hosted-runners-usage/>
- Limites do Let's Encrypt: <https://letsencrypt.org/docs/rate-limits/>
