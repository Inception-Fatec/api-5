# Backend — Docker

Spring Boot em container próprio (`tecsys-backend`), porta **8081**.
Imagem multi-stage: compila o jar com Maven+JDK 17 e roda com JRE 17 +
Python 3.12 (venv em `/opt/etl-venv` com o `modules/requirements.txt`), porque
o upload de geodatabase executa o ETL `modules/etl_cli.py` dentro do container.

O build precisa da pasta `modules/` como contexto nomeado `modules`. O
`docker compose` e o `run-backend.sh` já passam isso; à mão seria:

```bash
docker build --build-context modules=modules -t tecsys-backend Backend/tecsys
```

Variáveis do ETL: `ETL_DB_URL` (banco onde o ETL grava, formato SQLAlchemy:
`postgresql+psycopg2://usuario:senha@host:porta/banco`), definida pelo compose
e pelo script. Os CSVs da ANEEL baixados ficam no volume `tecsys-aneel-cache`.

## Como rodar

```bash
./scripts/run-backend.sh                 # contra o PostGIS local (localhost:5433)
./scripts/run-backend.sh --db supabase   # contra o Supabase
./scripts/run-backend.sh --stop          # para/remove o container
```

## Banco: local × Supabase

- `--db local` (padrão): `DB_URL=jdbc:postgresql://host.docker.internal:5433/tecsys`
  (precisa do `run-db.sh` rodando).
- `--db supabase`: lê `Backend/tecsys/.env.supabase` (crie a partir do
  `.env.supabase.example`, **nunca commitar**). Formato aceito:
  `SUPABASE_DB_URL=postgres://...` ou `postgresql://...` (como o
  dashboard mostra)
  — o script converte sozinho para o JDBC que o Spring exige.
  Detalhe: o host direto do Supabase é IPv6-only, que não existe na rede
  bridge padrão do Docker — por isso nesse modo o container usa
  `--network host`. Alternativa futura: usar a URL do pooler (IPv4).

A tabela `projects` (que não vem no dump) é criada sozinha pelo
Hibernate no primeiro boot, nos dois bancos.

## Logs

```bash
docker logs -f tecsys-backend
```

## Problemas comuns

- Chamadas devolvem 401 — sessão expirou (token JWT dura 2h): faça login de novo. 403 é falta de permissão (ex.: tela de ADM).
  de novo no app.
- `URL must start with 'jdbc'` no log — `.env.supabase` no formato errado;
  confira o prefixo `postgres://`.
- Carga ETL falha com `Script de ETL não encontrado`: imagem antiga, sem o
  Python. Refaça o build (`docker compose up -d --build backend`).
- Login: `admin@tecsys.com.br` / `admin123`.
