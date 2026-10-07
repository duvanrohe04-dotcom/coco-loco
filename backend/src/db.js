import { mkdirSync, readdirSync, readFileSync } from 'node:fs';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { DatabaseSync } from 'node:sqlite';

const MIGRATIONS_DIR = new URL('../migrations/', import.meta.url);
const FILE_RE = /^(\d{3})_[a-z0-9_]+\.sql$/;

/** Lee las migraciones de /migrations, ordenadas por nombre. */
function listMigrations(dir) {
  return readdirSync(fileURLToPath(dir))
    .filter((f) => f.endsWith('.sql'))
    .sort()
    .map((file) => {
      if (!FILE_RE.test(file)) throw new Error(`Nombre de migración no válido: ${file} (usa NNN_descripcion.sql)`);
      return { version: file, sql: readFileSync(new URL(file, dir), 'utf8') };
    });
}

/**
 * Aplica las migraciones pendientes, cada una en su propia transacción.
 * @returns {string[]} versiones aplicadas en esta llamada
 */
export function migrate(db, dir = MIGRATIONS_DIR) {
  db.exec(`CREATE TABLE IF NOT EXISTS schema_migrations (
    version    TEXT PRIMARY KEY,
    applied_at INTEGER NOT NULL
  )`);
  const done = new Set(db.prepare('SELECT version FROM schema_migrations').all().map((r) => r.version));
  const applied = [];
  for (const m of listMigrations(dir)) {
    if (done.has(m.version)) continue;
    db.exec('BEGIN');
    try {
      db.exec(m.sql);
      db.prepare('INSERT INTO schema_migrations (version, applied_at) VALUES (?, ?)').run(m.version, Date.now());
      db.exec('COMMIT');
    } catch (e) {
      db.exec('ROLLBACK');
      throw new Error(`Falló la migración ${m.version}: ${e.message}`);
    }
    applied.push(m.version);
  }
  return applied;
}

/** Abre (y crea si hace falta) la base de datos SQLite y la deja al día. */
export function openDb(path, migrationsDir) {
  if (path !== ':memory:') mkdirSync(dirname(path), { recursive: true });
  const db = new DatabaseSync(path);
  db.exec('PRAGMA journal_mode = WAL; PRAGMA foreign_keys = ON;');
  const applied = migrate(db, migrationsDir);
  if (applied.length && path !== ':memory:') console.log(`Migraciones aplicadas: ${applied.join(', ')}`);
  return db;
}
