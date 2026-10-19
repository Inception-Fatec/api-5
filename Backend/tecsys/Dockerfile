# ---- stage 1: build do jar ----
FROM maven:3.9.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn -q -DskipTests package

# ---- stage 2: runtime enxuto (só JRE) ----
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=build /app/target/tecsys-*.jar app.jar
EXPOSE 8081
# Conexão com o banco vem por variáveis de ambiente (DB_URL, DB_USER,
# DB_PASSWORD) — ver scripts/run-backend.sh. Não embarcar .env na imagem.
ENTRYPOINT ["java", "-jar", "app.jar"]
