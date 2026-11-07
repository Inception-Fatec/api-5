-- Extensão espacial (colunas geometry)
CREATE EXTENSION IF NOT EXISTS postgis;

-- Enum de perfis de usuário (espelha com.tecsys.domain.user.UserRole)
CREATE TYPE user_role AS ENUM ('ADM', 'USER');