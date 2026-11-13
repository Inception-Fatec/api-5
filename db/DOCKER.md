# Banco de dados (PostgreSQL + PostGIS)

PostGIS 17 (`postgis/postgis:17-3.6-alpine`) em container próprio, `tecsys-postgis`, porta **5433** no host (a 5432 costuma estar ocupada por outro Postgres). Dados persistidos no volume Docker `tecsys-pgdata`.

## Dados de conexão (local)

| Item | Valor |
|---|---|
| Host / porta | `localhost:5433` |
| Banco | `tecsys` |
| Usuário / senha | `tecsys` / `tecsys` |
| URL | `postgres://tecsys:tecsys@localhost:5433/tecsys` |

Dentro da rede `tecsys-net`, os containers acessam o banco por `tecsys-postgis:5432`; no `docker compose`, por `db:5432`.

## Como rodar

```bash
./scripts/run-db.sh                  # sobe o container e, se o banco estiver vazio, cria o schema e carrega o dump
./scripts/run-db.sh --dump ~/x.dump  # usa outro dump
./scripts/run-db.sh --stop           # para e remove o container (dados permanecem no volume)
```

O backend e o motor escolhem entre este banco e o Supabase por `./scripts/run-backend.sh --db local|supabase` e `./scripts/run-motor.sh --db local|supabase`.

## Como o banco é montado

A carga só acontece com o banco vazio (tabela `sub` ausente ou zerada).

1. **Schema.** O script executa as migrations do Flyway (`Backend/tecsys/src/main/resources/db/migration`, `V1` a `V15`) num container `flyway/flyway` na mesma versão do backend. O schema é de responsabilidade do backend: alterações entram como nova migration, nunca por edição manual do banco. As extensões são criadas pelas próprias migrations (`postgis` na `V1`, `pgcrypto` na `V9`).
2. **Usuário administrador.** A migration `V9` cria `admin@tecsys.com.br` / `admin123` (perfil `ADM`).
3. **Dados da rede.** O script restaura do `bdgd.dump` somente os dados (`--data-only`) das tabelas do dump, exceto `users` (vem da `V9`) e `spatial_ref_sys` (vem da extensão PostGIS). Na prática, são as tabelas da rede: `sub`, `untrat`, `untrmt`, `ssdat`, `ssdmt`, `ssdbt`, `ucat_pj`, `ucmt_pj`, `ucbt`.

Antes da #TG-142, o dump era restaurado inteiro, com `users` e sem o histórico do Flyway, e o backend falhava com `Migration V2__create_users.sql failed: relation "users" already exists`. Se o seu volume foi criado assim, o script avisa; recrie-o:

```bash
./scripts/run-db.sh --stop && docker volume rm tecsys-pgdata && ./scripts/run-db.sh
```

### Onde colocar o dump (apenas na 1ª subida)

O banco local não vem populado. Obtenha o `bdgd.dump` com a equipe e salve em `db/bdgd.dump` (ignorado pelo Git) ou aponte com `--dump CAMINHO`. Ordem de busca: `--dump` → `db/bdgd.dump` → `~/Documents/bdgd.dump`. Depois do primeiro restore, os dados ficam no volume e o arquivo não é mais necessário.

## Modelo de dados (resumo)

| Grupo | Tabelas | Origem |
|---|---|---|
| Rede elétrica | `sub`, `untrat`, `untrmt`, `ssdat`, `ssdmt`, `ssdbt` | BDGD (dump ou ETL) |
| Consumidores | `ucat_pj`, `ucmt_pj`, `ucbt` | BDGD (dump ou ETL); `ucbt.qtd_consumidores` é o peso no motor |
| Aplicação | `users`, `projects`, `project_history`, `project_coverage`, `etl_jobs`, tabela de distribuidoras | Migrations do Flyway |

Os dados de rede usam SIRGAS 2000 (EPSG:4674). Documentação de referência em `docs/` (`modelo_banco_dados_postgis-2.docx.pdf`, `documento_consolidado_bdgd.docx.pdf`).

## Docker Compose

O serviço `db` do `docker-compose.yml` usa a mesma imagem, o mesmo nome de container (`tecsys-postgis`) e a mesma porta (5433), mas mantém os dados em um volume do próprio projeto compose e **nasce vazio**. Não suba o banco pelo compose e pelo `run-db.sh` ao mesmo tempo. Para carregar a rede no banco do compose:

```bash
docker compose up -d db
./scripts/run-db.sh
docker compose up --build -d
```

## Local × Supabase

| | Local (este container) | Supabase |
|---|---|---|
| Latência em consultas pesadas (~193 mil pontos) | Baixa | Maior (rede) |
| Extensões | Já vêm na imagem | Habilitar `postgis` e `pgcrypto` no projeto |
| Carga do dump | Automática pelo script | Manual: `pg_restore` contra a connection string |
| Uso | Desenvolvimento com grandes volumes | Desenvolvimento leve; compartilhar base com a equipe |

Para o Supabase, o ETL pela tela da aplicação grava a baixa tensão agregada por ponto de conexão, para caber no plano gratuito (500 MB). Ver [`modules/README.md`](../modules/README.md#baixa-tensão).

## Problemas comuns

- `pg_restore: unsupported version`: restaure sempre de dentro do container (o script já faz); o `pg_restore` do host pode ser mais antigo que o dump.
- Porta 5433 ocupada: há outro `tecsys-postgis` em execução? `docker ps` e `./scripts/run-db.sh --stop`.
- Backend falha com `relation "users" already exists`: volume criado por versão antiga do script; recriar conforme indicado acima.
- Para recomeçar do zero: parar o container e `docker volume rm tecsys-pgdata`.
