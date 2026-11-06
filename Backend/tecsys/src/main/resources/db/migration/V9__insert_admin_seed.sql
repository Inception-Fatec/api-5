CREATE EXTENSION IF NOT EXISTS pgcrypto;

INSERT INTO users (name, email, password_hash, role, must_change_password, is_active)
VALUES (
    'Admin Tecsys',
    'admin@tecsys.com.br',
    crypt('admin123', gen_salt('bf', 10)),
    'ADM',
    false,
    true
) ON CONFLICT (email) DO NOTHING;