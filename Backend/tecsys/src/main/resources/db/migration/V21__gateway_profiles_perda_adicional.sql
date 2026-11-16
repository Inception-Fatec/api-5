-- #TG-150: perda adicional do enlace (vegetação, construções, paredes), em dB.
-- No espaço livre o sinal da Tecsys alcançaria ~290 km e o limite real seria
-- sempre o horizonte de rádio (~19 km com antenas de 6 m e 5 m); com a perda
-- adicional, potência e sensibilidade passam a influir no alcance.
-- 0 dB = comportamento anterior (espaço livre).
ALTER TABLE gateway_profiles ADD COLUMN IF NOT EXISTS extra_loss_db DOUBLE PRECISION NOT NULL DEFAULT 0.0;
