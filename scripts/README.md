# Scripts

Scripts Bash que sobem e param a stack em containers Docker. Todos são idempotentes: executar de novo recria apenas o que mudou.

## Pré-requisitos

- Docker com o plugin `docker compose` e o usuário no grupo `docker`.
- Portas livres: 5433 (banco), 8081 (backend), 8082 (motor, apenas `127.0.0.1`) e 8080 (frontend).
- `API_SECURITY_TOKEN_SECRET` definido no ambiente ou em `.env` na raiz do repositório (mínimo de 32 bytes). Sem ele o `run-backend.sh` aborta.

  ```bash
  echo "API_SECURITY_TOKEN_SECRET=$(openssl rand -hex 32)" > .env
  ```

- `db/bdgd.dump`: apenas na primeira subida do banco local (ver [Dump do banco](#dump-do-banco)).
- `Backend/tecsys/.env.supabase` e `MOTOR/.env.supabase`: apenas no modo Supabase. Nunca versionar.

## Orquestradores

| Script | Banco | Uso |
|---|---|---|
| `./scripts/up-local.sh` | PostGIS local (container, porta 5433) | Desenvolvimento com grandes volumes; consultas espaciais rápidas |
| `./scripts/up-supabase.sh` | Supabase (nuvem) | Base compartilhada pela equipe; sem container de banco |

Ambos sobem backend, motor e frontend e imprimem as URLs ao final. `--stop` para os containers que o script subiu; os dados do banco local permanecem no volume Docker.

```bash
./scripts/up-local.sh              # stack completa com banco local
./scripts/up-local.sh --stop

./scripts/up-supabase.sh           # stack com banco na nuvem
./scripts/up-supabase.sh --stop
```

Ordem de subida do `up-local.sh`: banco → backend → motor → frontend. O motor depende do schema aplicado pelo Flyway no startup do backend (inclusive `project_coverage`).

```mermaid
flowchart LR
    UP{{"./scripts/up-local.sh"}}
    DUMP[/"db/bdgd.dump<br/>só na 1ª subida"/]
    ENV[/".env<br/>API_SECURITY_TOKEN_SECRET"/]

    DB["1. run-db.sh<br/>PostGIS :5433"]
    BE["2. run-backend.sh<br/>Spring Boot :8081"]
    MT["3. run-motor.sh<br/>Motor :8082"]
    FE["4. run-frontend.sh<br/>Flutter + nginx :8080"]

    UP ==> DB
    DUMP -.->|"dados da rede"| DB
    DB ==>|"Flyway cria o schema"| BE
    ENV -.->|"segredo do JWT"| BE
    BE ==>|"schema pronto<br/>(project_coverage)"| MT
    MT ==> FE
    BE -.->|"URL da API<br/>embutida no build"| FE

    classDef cmd fill:#fff3e0,stroke:#e65100,color:#0d1b2a
    classDef svc fill:#e0f2f1,stroke:#006a60,color:#0d1b2a
    classDef inp fill:#f5f5f5,stroke:#757575,color:#0d1b2a
    class UP cmd
    class DB,BE,MT,FE svc
    class DUMP,ENV inp
```

## Scripts individuais

Para reiniciar ou reconstruir uma parte sem mexer no resto.

| Script | Opções | Container / porta | Descrição |
|---|---|---|---|
| `run-db.sh` | `[--dump CAMINHO] [--stop]` | `tecsys-postgis` / 5433 | PostGIS 17. Com o banco vazio, aplica as migrations do Flyway e carrega os dados da rede do dump |
| `run-backend.sh` | `[--db local\|supabase] [--stop]` | `tecsys-backend` / 8081 | Reconstrói a imagem (via `docker compose build`, sem exigir buildx) e sobe o Spring Boot |
| `run-motor.sh` | `[--db local\|supabase] [--stop]` | `tecsys-motor` / 8082 | Motor de decisão. Repassa ao container as linhas `MOTOR_*` e `DEM_*` do arquivo de ambiente |
| `run-frontend.sh` | `[--api-host HOST] [--api-port PORT] [--stop]` | `tecsys-frontend` / 8080 | Flutter Web no nginx. A URL da API é embutida no build; mudar o backend reconstrói a imagem |
| `sync-dem-mirror.sh` | `--mirror-dir DIR (--bbox S,N,W,E \| --tiles TILE[,TILE...])` | n/a | Baixa tiles do Copernicus GLO-30 (AWS Open Data) para o mirror local/NAS, sem AWS CLI e sem credenciais; atualiza `manifest.sha256` |

Notas:
- **Supabase:** `--db supabase` lê `Backend/tecsys/.env.supabase` (criar a partir do `.env.supabase.example`) e `MOTOR/.env.supabase`. Os formatos `postgres://` e `postgresql://` são aceitos; o script converte para JDBC. O host direto do Supabase é IPv6-only, por isso o backend usa `--network host` nesse modo (ver [`Backend/tecsys/DOCKER.md`](../Backend/tecsys/DOCKER.md)).
- **Motor:** sem autenticação; a porta é publicada somente em `127.0.0.1`. O relevo vem da AWS sem chave de API. Mirror opcional via `DEM_MIRROR_DIR` (montado somente leitura). Ver [`MOTOR/README.md`](../MOTOR/README.md) e [`docs/MOTOR_RELEVO_AWS.md`](../docs/MOTOR_RELEVO_AWS.md).
- **Banco:** detalhes em [`db/DOCKER.md`](../db/DOCKER.md).

### Alternativa com `docker compose`

```bash
docker compose up --build              # db + backend + motor + frontend
docker compose up --build db           # apenas um serviço
docker compose down                    # para tudo e preserva os volumes (banco e caches)
docker compose down -v                 # remove também os volumes, incluindo os caches de relevo e ANEEL
```

O segredo do JWT vem do ambiente ou do `.env` da raiz. O banco do compose nasce vazio; para carregar a rede do dump:

```bash
docker compose up -d db
./scripts/run-db.sh                    # migrations + dados da rede no banco do compose
docker compose up --build -d
```

Para usar o Supabase no backend, suba-o por `./scripts/run-backend.sh --db supabase` em vez do compose.

## Dump do banco

O banco local não vem populado. Na primeira subida, `run-db.sh` precisa do `bdgd.dump`, resolvido nesta ordem:

1. `--dump CAMINHO`
2. `db/bdgd.dump` (convenção; ignorado pelo Git)
3. `~/Documents/bdgd.dump` (legado)

```bash
./scripts/run-db.sh --dump ~/meus-arquivos/bdgd.dump
```

Montagem do banco vazio:

1. **Tabelas:** o script executa as migrations do Flyway (`Backend/tecsys/src/main/resources/db/migration`) num container `flyway/flyway` na mesma versão do backend. O backend encontra o schema em dia e o administrador (`admin@tecsys.com.br`) vem da migration V9.
2. **Dados:** restaura do dump somente os dados das tabelas da rede (`sub`, `untrat`, `untrmt`, `ssdat`, `ssdmt`, `ssdbt`, `ucat_pj`, `ucmt_pj`, `ucbt`). `users` e `spatial_ref_sys` ficam de fora.

Depois do primeiro restore, os dados ficam no volume `tecsys-pgdata` e o arquivo deixa de ser necessário. Para recomeçar do zero: `./scripts/run-db.sh --stop && docker volume rm tecsys-pgdata && ./scripts/run-db.sh`.

Se o volume foi criado por uma versão antiga do script (dump restaurado inteiro, com `users` e sem o histórico do Flyway), o backend falha com `Migration V2__create_users.sql failed: relation "users" already exists` (#TG-142). O script avisa nesse caso; recrie o volume com o comando acima.

## Dados adicionais: baixa tensão

O upload de `.gdb` pela tela **ETL & Geodados** carrega rede, consumidores de média e alta tensão e consumidores de baixa tensão da própria geodatabase. Funcionamento e regras de reenvio em [`modules/README.md`](../modules/README.md#baixa-tensão).

## Credenciais de desenvolvimento

| Recurso | Valor |
|---|---|
| Login do app | `admin@tecsys.com.br` / `admin123` |
| Banco local | `postgres://tecsys:tecsys@localhost:5433/tecsys` |

## Problemas comuns

| Sintoma | Causa e ação |
|---|---|
| `ERRO: API_SECURITY_TOKEN_SECRET não definida` | Definir a variável ou criar `.env` na raiz (ver pré-requisitos) |
| 401 nas chamadas | Token JWT expirado (validade de 2 h); o app volta ao login. 403 indica falta de permissão (ex.: rota de `ADM`) |
| Cidade não seleciona ou salvar não funciona | Quase sempre sessão expirada; fazer login antes de investigar o banco |
| Backend em modo Supabase não sobe | Host direto do Supabase é IPv6-only e não existe na rede bridge do Docker; o script usa `--network host`. Não trocar para bridge sem ler `Backend/tecsys/DOCKER.md` |
| `URL must start with 'jdbc'` | `.env.supabase` com formato incorreto; usar o prefixo `postgres://` ou `postgresql://` |
| Porta ocupada | Outro container ou serviço na mesma porta: `docker ps` e o `--stop` correspondente |
| `pg_restore: unsupported version` | Restaurar de dentro do container (o `run-db.sh` já faz); o `pg_restore` do host é mais antigo que o dump |
| Projeto vai para `FALHA` com "Motor de cálculo indisponível" | Motor fora do ar ou inalcançável pelo backend (`ENGINE_URL`); subir o motor e recalcular o projeto |
| Projeto parado em `ENVIADO` ou `PROCESSANDO` | O cálculo ainda está rodando (áreas grandes levam minutos) ou o motor foi reiniciado no meio; verificar `docker logs tecsys-motor` |
| Projeto termina em `FALHA` | Ver o motivo em `docker logs tecsys-motor` (por exemplo, relevo indisponível) |
| Frontend sem dados após trocar de backend | Rebuild com o host correto (`--api-host`); conferir na aba Network (F12) o destino das chamadas `/api/v1/*` |
