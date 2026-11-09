# Módulo Backend (Tecsys)

## 1. O que faz e com quem conversa
Serviço central de API REST desenvolvido em Node.js (Express), responsável por gerenciar regras de negócio, persistência de projetos, autenticação de usuários e orquestração de simulações.
- **Comunicação:** Recebe requisições HTTP do **Frontend (Flutter)**, consulta e persiste dados geoespaciais no **PostgreSQL/PostGIS**, e dispara chamadas de cálculo para o **Motor de Decisão (Python)**.

## 2. Como executar

### Pré-requisitos
- Node.js v18 LTS ou superior
- Instância ativa do PostgreSQL com a extensão PostGIS habilitada

### Variáveis de Ambiente (`.env`)
Crie um arquivo `.env` dentro do diretório `Backend/tecsys/`:
```env
PORT=3000
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/bdgd_db
JWT_SECRET=sua_chave_jwt_secreta_aqui
MOTOR_API_URL=http://localhost:5000
