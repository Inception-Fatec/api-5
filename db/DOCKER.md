# Banco — Docker

PostGIS 17 em container próprio (`tecsys-postgis`), porta **5433** (a 5432
geralmente já está ocupada por outro Postgres, ex. `pdv-postgres`).

## Como rodar

```bash
./scripts/run-db.sh                 # sobe + restaura o bdgd.dump se estiver vazio
./scripts/run-db.sh --dump ~/x.dump # usa outro dump
./scripts/run-db.sh --stop          # para/remove o container (dados ficam no volume)
```

O restore só acontece com o banco vazio (tabela `sub` ausente ou zerada).
Para forçar um restore do zero: `docker volume rm tecsys-pgdata` com o
container parado e rode o script de novo.

## Dados de conexão (local)

- Host: `localhost:5433` · banco `tecsys` · user/senha `tecsys`
- URL: `postgres://tecsys:tecsys@localhost:5433/tecsys`

## Local × Supabase

| | Local (este container) | Supabase |
|---|---|---|
| Latência em queries pesadas (193k pontos) | baixa | maior (rede) |
| Extensões | já vêm na imagem | habilitar `postgis` + `pgcrypto` no projeto |
| Restore do dump | automático pelo script | manual: `pg_restore` contra a connection string |
| Uso | dev com grandes volumes | dev leve / compartilhar base com a equipe |

O backend escolhe entre os dois com `./scripts/run-backend.sh --db local|supabase`.

## Problemas comuns

- `pg_restore: unsupported version` — restaure sempre **de dentro do
  container** (o script já faz isso); o `pg_restore` do host pode ser
  mais antigo que o dump.
- Porta 5433 ocupada — outro `tecsys-postgis` rodando? `docker ps` e
  `--stop` o antigo.
