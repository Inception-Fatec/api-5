# ---- stage 1: build do jar ----
FROM maven:3.9.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
# -Dmaven.test.skip=true nem compila os testes: a imagem não depende deles.
RUN mvn -q -Dmaven.test.skip=true package

# ---- stage 2: runtime enxuto (só JRE) ----
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=build /app/target/tecsys-motor-*.jar app.jar
EXPOSE 8082
# Banco e chave do relevo vêm por variáveis de ambiente (DB_URL, DB_USER,
# DB_PASSWORD, OPENTOPOGRAPHY_API_KEY, MOTOR_BIND_ADDRESS) — ver
# scripts/run-motor.sh. Não embarcar .env na imagem.
ENTRYPOINT ["java", "-jar", "app.jar"]
