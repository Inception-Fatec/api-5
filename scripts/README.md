# Scripts — como rodar o projeto

Cada serviço tem seu `.sh` individual, e há dois orquestradores que sobem
a stack inteira. Todos são idempotentes: pode rodar de novo sem medo.

## Orquestradores (uso do dia a dia)

| Script | Banco | Quando usar |
|---|---|---|
| `./scripts/up-local.sh` | PostGIS local (container, porta 5433) | dev com grandes volumes; queries espaciais rápidas |
| `./scripts/up-supabase.sh` | Supabase (nuvem) | base compartilhada com a equipe; sem container de banco |

Ambos sobem backend (8081) + frontend (8080) e terminam imprimindo as URLs.
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
# PostGIS 17 (tecsys-postgis). Restaura o bdgd.dump automaticamente
# só se o banco estiver vazio. Conexão: postgres://tecsys:tecsys@localhost:5433/tecsys

### Onde colocar o dump (só necessário na 1ª subida)

O banco local **não** vem populado: na primeira vez, o `run-db.sh` precisa
do arquivo `bdgd.dump`. Resolução nesta ordem: `--dump CAMINHO` →
`api-5/db/bdgd.dump` → `~/Documents/bdgd.dump`.

```bash
# convenção: pegue o dump com a equipe e coloque aqui (é gitignored)
api-5/db/bdgd.dump
# ou aponte direto:
./scripts/run-db.sh --dump ~/meus-arquivos/bdgd.dump
```

Após o primeiro restore os dados ficam no volume Docker (`tecsys-pgdata`)
e o arquivo não é mais necessário. Para recomeçar do zero:
`docker volume rm tecsys-pgdata` (container parado) e suba de novo.

./scripts/run-backend.sh [--db local|supabase] [--stop]
# Spring Boot (tecsys-backend, porta 8081). Rebuilda a imagem do código atual.
# --db supabase lê Backend/tecsys/.env.supabase (criar a partir do
# .env.supabase.example; nunca commitar). Formatos aceitos: postgres:// ou
# postgresql:// — o script converte para JDBC sozinho.

./scripts/run-frontend.sh [--api-host HOST] [--api-port PORT] [--stop]
# Flutter web no nginx (tecsys-frontend, porta 8080). A URL da API é
# embutida no build: trocou de backend, o script rebuilda sozinho.
```

Alternativa "sobe tudo": `docker compose up --build` (usa os mesmos
Dockerfiles; o backend do compose fala com o banco local).

## Pré-requisitos

- Docker (único requisito com sudo/sem sudo: o usuário precisa estar no grupo `docker`)
- `.env.supabase` preenchido (só para o modo nuvem)
- Portas livres: 5433 (banco) · 8081 (backend) · 8080 (frontend)
- Login do app: `admin@tecsys.com.br` / `admin123`

## Problemas comuns

- **Sessão expirada (403)**: o token JWT dura 2h — faça logout/login de novo no app.
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
