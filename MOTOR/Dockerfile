# ---- stage 1: build do jar ----
FROM maven:3.9.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
# -Dmaven.test.skip=true nem compila os testes: a imagem não depende deles.
RUN mvn -q -Dmaven.test.skip=true package

# ---- stage 2: runtime (só JRE) ----
# Ubuntu e não Alpine: o solver (OR-Tools) traz bibliotecas nativas que precisam de glibc.
FROM eclipse-temurin:17-jre-jammy
WORKDIR /app
COPY --from=build /app/target/tecsys-motor-*.jar app.jar
EXPOSE 8082
# Relevo Copernicus GLO-30 (AWS Open Data, sem chave): monte um volume aqui
# para não baixar de novo a cada container. Ver scripts/run-motor.sh.
ENV DEM_CACHE_DIR=/var/cache/tecsys-dem
RUN mkdir -p /var/cache/tecsys-dem
VOLUME /var/cache/tecsys-dem
# Banco e ajustes do relevo vêm por variáveis de ambiente (DB_URL, DB_USER,
# DB_PASSWORD, DEM_MIRROR_DIR, MOTOR_BIND_ADDRESS) — ver scripts/run-motor.sh.
# Não embarcar .env na imagem.
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "app.jar"]
