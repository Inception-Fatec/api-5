# Backend — Docker

Spring Boot em container próprio (`tecsys-backend`), porta **8081**.
Imagem multi-stage: compila o jar com Maven+JDK 17 e roda só com JRE 17.

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
  `SUPABASE_DB_URL=postgres://usuario:senha@host:5432/banco`
  — o script converte sozinho para o JDBC que o Spring exige.

A tabela `projects` (que não vem no dump) é criada sozinha pelo
Hibernate no primeiro boot, nos dois bancos.

## Logs

```bash
docker logs -f tecsys-backend
```

## Problemas comuns

- Login devolve 403 — sessão expirou (token JWT dura 2h): faça logout/login
  de novo no app.
- `URL must start with 'jdbc'` no log — `.env.supabase` no formato errado;
  confira o prefixo `postgres://`.
- Login: `admin@tecsys.com.br` / `admin123`.
