# Scripts — como rodar o projeto

Cada serviço tem seu `.sh` individual, e há dois orquestradores que sobem
a stack inteira. Todos são idempotentes: pode rodar de novo sem medo.

## Orquestradores (uso do dia a dia)

| Script | Banco | Quando usar |
|---|---|---|
| `./scripts/up-local.sh` | PostGIS local (container, porta 5433) | dev com grandes volumes; queries espaciais rápidas |
| `./scripts/up-supabase.sh` | Supabase (nuvem) | base compartilhada com a equipe; sem container de banco |

Ambos sobem backend (8081) + motor de decisão (8082) + frontend (8080) e terminam imprimindo as URLs.
`--stop` em qualquer um deles para os containers que ele subiu (os dados do
banco local ficam preservados no volume Docker).

```bash
./scripts/up-local.sh            # stack completa local
./scripts/up-local.sh --stop

./scripts/up-supabase.sh         # stack com banco na nuvem (precisa do .env.supabase)
./scripts/up-supabase.sh --stop
```

## Scripts individuais (um serviço por vez)

Para rebuildar/reiniciar só uma parte, sem mexer no resto:

```bash
./scripts/run-db.sh [--dump CAMINHO] [--stop]
```

PostGIS 17 (`tecsys-postgis`). Se o banco estiver vazio, cria as tabelas pelas
migrations do Flyway e carrega os dados da rede do `bdgd.dump` (ver "Onde
colocar o dump"). Conexão: `postgres://tecsys:tecsys@localhost:5433/tecsys`.

```bash
./scripts/run-backend.sh [--db local|supabase] [--stop]
```

Spring Boot (`tecsys-backend`, porta 8081). Rebuilda a imagem do código atual.
`--db supabase` lê `Backend/tecsys/.env.supabase` (criar a partir do
`.env.supabase.example`; nunca commitar). Formatos aceitos: `postgres://` ou
`postgresql://` — o script converte para JDBC sozinho.

```bash
./scripts/run-motor.sh [--db local|supabase] [--stop]
```

Motor de decisão (`tecsys-motor`, porta 8082, só em 127.0.0.1 — não tem
autenticação; quem chama é o backend). Mesmo esquema de banco do backend
(`--db supabase` lê `MOTOR/.env.supabase`). O relevo usa o Copernicus GLO-30
no AWS Open Data, sem chave de API. O mirror local/NAS é opcional e definido
por `DEM_MIRROR_DIR` no arquivo de ambiente; o script monta o diretório
read-only. Para semear o mirror, use `./scripts/sync-dem-mirror.sh`.

```bash
./scripts/sync-dem-mirror.sh --mirror-dir DIR --bbox S,N,W,E
./scripts/sync-dem-mirror.sh --mirror-dir DIR --tiles TILE[,TILE...]
```

Baixa tiles do Copernicus GLO-30 do AWS Open Data para o mirror local/NAS,
sem AWS CLI e sem credenciais. Atualiza `manifest.sha256`. Ver
[`docs/MOTOR_RELEVO_AWS.md`](../docs/MOTOR_RELEVO_AWS.md).

```bash
./scripts/run-frontend.sh [--api-host HOST] [--api-port PORT] [--stop]
```

Flutter web no nginx (`tecsys-frontend`, porta 8080). A URL da API é embutida
no build: trocou de backend, o script rebuilda sozinho.

Alternativa "sobe tudo": `docker compose up --build` (usa os mesmos
Dockerfiles; sobe banco local, backend, motor e frontend). O segredo do JWT
vem do ambiente ou do `.env` da raiz: `API_SECURITY_TOKEN_SECRET=...` (gere com
`openssl rand -hex 32`). O motor não precisa de chave: o relevo vem da AWS.
O banco do compose nasce vazio; para carregar a rede do `bdgd.dump` nele:

```bash
docker compose up -d db
./scripts/run-db.sh          # migrations + dados da rede no banco do compose
docker compose up --build -d
```

## Onde colocar o dump (só necessário na 1ª subida)

O banco local **não** vem populado: na primeira vez, o `run-db.sh` precisa
do arquivo `bdgd.dump`. Resolução nesta ordem: `--dump CAMINHO` →
`api-5/db/bdgd.dump` → `~/Documents/bdgd.dump`.

```bash
# convenção: pegue o dump com a equipe e coloque aqui (é gitignored)
api-5/db/bdgd.dump
# ou aponte direto:
./scripts/run-db.sh --dump ~/meus-arquivos/bdgd.dump
```

Como o banco é montado (banco vazio):

1. **Tabelas:** o script roda as migrations do Flyway (`Backend/tecsys/src/main/resources/db/migration`)
   num container `flyway/flyway` na mesma versão do backend. Assim o backend encontra o
   banco já em dia ("Schema is up to date") e o admin (`admin@tecsys.com.br`) vem da V9.
2. **Dados:** carrega do dump só os dados das tabelas da rede (`sub`, `untrat`, `untrmt`,
   `ssdat`, `ssdmt`, `ssdbt`, `ucat_pj`, `ucmt_pj`, `ucbt`); `users` e `spatial_ref_sys`
   ficam de fora.

Antes, o dump era restaurado inteiro, com a tabela `users` e sem o histórico do Flyway, e o
backend caía com `Migration V2__create_users.sql failed: relation "users" already exists`
(#TG-142). Se o seu volume é desse jeito, o script avisa; recrie com:

```bash
./scripts/run-db.sh --stop && docker volume rm tecsys-pgdata && ./scripts/run-db.sh
```

Após o primeiro restore os dados ficam no volume Docker (`tecsys-pgdata`)
e o arquivo não é mais necessário. Para recomeçar do zero:
`docker volume rm tecsys-pgdata` (container parado) e suba de novo.

## Baixa tensão no upload de geodatabase (preload_ucbt)

O upload de `.gdb` pela tela **ETL & Geodados** carrega a rede e os
consumidores de média/alta tensão, mas **não** os de baixa tensão. Os
consumidores BT vêm do arquivo nacional da ANEEL (`ucbt_pj.zip`, ~1,3 GB),
que é carregado à parte, uma vez por distribuidora, na tabela `ucbt_raw`.
Na carga do `.gdb`, o ETL liga esses consumidores aos transformadores.

Se a `ucbt_raw` não tiver a distribuidora, a carga termina em **Concluído**
com o aviso "Baixa tensão não carregada" no card e nos detalhes. Para
resolver, rode o preload e envie o `.gdb` de novo:

```bash
cd modules
pip install -r requirements.txt          # 1ª vez
# ETL_DB_URL no modules/.env (ver .env.example); para o banco local:
# ETL_DB_URL=postgresql+psycopg2://tecsys:tecsys@localhost:5433/tecsys
python preload_ucbt.py --distribuidoras 391   # código DIST da distribuidora
```

O download fica em cache (`cache_aneel/`), então rodar para outra
distribuidora não baixa o arquivo de novo.

## Pré-requisitos

- Docker instalado, com o usuário no grupo `docker`
- `bdgd.dump` (só para a primeira subida do banco local — ver seção acima)
- `.env.supabase` preenchido (só para o modo nuvem)
- Portas livres: 5433 (banco) · 8081 (backend) · 8080 (frontend)
- Login do app: `admin@tecsys.com.br` / `admin123`

## Problemas comuns

- **Sessão expirada (401)**: o token JWT dura 2h — o app volta para o login sozinho. 403 é falta de permissão (ex.: rota de ADM).
- **Cidade não seleciona / salvar não funciona**: quase sempre é a sessão
  expirada acima, não o banco. Relogue antes de investigar mais.
- **Backend modo supabase não sobe**: o host direto do Supabase é IPv6-only
  (fora da rede bridge do Docker) — por isso o script usa `--network host`
  nesse modo. Não troque para bridge sem ler `Backend/tecsys/DOCKER.md`.
- **Porta ocupada**: outro container/serviço na mesma porta? `docker ps` e
  use o `--stop` correspondente.
- **`pg_restore: unsupported version`**: restaure sempre de dentro do
  container (o `run-db.sh` já faz isso); o `pg_restore` do host é antigo demais
  para o dump.
- **Frontend sem dados após trocar de backend**: rebuild com o host certo
  (`--api-host`); confira na aba Network do DevTools (F12) para onde vão as
  chamadas `/api/v1/*`.
