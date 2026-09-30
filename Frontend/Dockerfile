# ---- stage 1: build web do Flutter ----
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app
COPY pubspec.* ./
RUN flutter pub get
COPY . .
# URL da API embutida no build (o browser chama o backend direto).
# Padrão = backend local na máquina do dev (ver scripts/run-frontend.sh).
ARG API_HOST=localhost
ARG API_PORT=8081
RUN flutter build web --release \
      --dart-define=API_HOST=${API_HOST} \
      --dart-define=API_PORT=${API_PORT}

# ---- stage 2: serve os estáticos ----
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
