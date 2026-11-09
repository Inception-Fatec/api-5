# Frontend — Docker

Flutter web em container próprio (`tecsys-frontend`, nginx), porta **8080**.
Imagem multi-stage: compila com o SDK Flutter e serve só os estáticos.

## Como rodar

```bash
./scripts/run-frontend.sh                                  # API em localhost:8081
./scripts/run-frontend.sh --api-host 192.168.0.10         # backend noutra máquina
./scripts/run-frontend.sh --api-host localhost --api-port 8081
./scripts/run-frontend.sh --stop                           # para/remove o container
```

## Importante: a URL da API é de build

O browser chama o backend **direto**, então host/porta são embutidos no
`flutter build web` via `--dart-define` (ver `Dockerfile` e
`lib/services/api_client.dart`). Trocou de backend? Rebuilda (o script já
faz isso). Fora do Docker, `flutter run` usa `localhost:8081` sem
precisar de nada.

## Problemas comuns

- App abre mas sem dados / tela travada no login — backend fora do ar ou
  `--api-host` errado. Confira na aba Network do DevTools (F12) para onde
  estão indo as chamadas `/api/v1/*`.
- Chamada bloqueada por CORS — o backend libera `http://localhost:*`;
  servindo o front de outro host, chame com o IP e garanta que o backend
  aceita aquela origem (ver `SecurityConfig`).
