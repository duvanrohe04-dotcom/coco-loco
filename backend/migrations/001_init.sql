-- 001: esquema inicial de Coco Loco.
-- Usa IF NOT EXISTS para poder aplicarse también sobre bases creadas antes de existir las migraciones.

CREATE TABLE IF NOT EXISTS users (
  id         INTEGER PRIMARY KEY,
  username   TEXT NOT NULL UNIQUE COLLATE NOCASE,   -- 3-16 caracteres, sin distinguir mayúsculas
  pass_salt  TEXT NOT NULL,                         -- sal aleatoria (hex)
  pass_hash  TEXT NOT NULL,                         -- scrypt(contraseña, sal) (hex)
  character  TEXT NOT NULL DEFAULT 'mochi',         -- personaje elegido
  created_at INTEGER NOT NULL                       -- milisegundos desde epoch
);

CREATE TABLE IF NOT EXISTS sessions (
  token_hash TEXT PRIMARY KEY,                      -- SHA-256 del token (el token nunca se guarda)
  user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at INTEGER NOT NULL                       -- milisegundos desde epoch
);
CREATE INDEX IF NOT EXISTS sessions_user ON sessions(user_id);

CREATE TABLE IF NOT EXISTS progress (
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  level   INTEGER NOT NULL,
  stars   INTEGER NOT NULL,                         -- mejor resultado: 0-3
  streak  INTEGER NOT NULL,                         -- mejor racha del nivel
  PRIMARY KEY (user_id, level)
);
