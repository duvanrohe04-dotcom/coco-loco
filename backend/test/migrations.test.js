import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, it } from 'node:test';
import { pathToFileURL } from 'node:url';
import { DatabaseSync } from 'node:sqlite';

import { migrate, openDb } from '../src/db.js';

/** Crea una carpeta temporal con migraciones { 'nombre.sql': 'SQL' }. */
function withMigrations(files, fn) {
  const dir = mkdtempSync(join(tmpdir(), 'cocoloco-mig-'));
  try {
    for (const [name, sql] of Object.entries(files)) writeFileSync(join(dir, name), sql);
    return fn(pathToFileURL(dir + '/'));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

const tables = (db) =>
  db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name").all().map((r) => r.name);

describe('migraciones SQL', () => {
  it('una base nueva queda con el esquema completo y se anota la versión', () => {
    const db = openDb(':memory:');
    assert.deepEqual(tables(db), ['progress', 'schema_migrations', 'sessions', 'users']);
    assert.deepEqual(
      db.prepare('SELECT version FROM schema_migrations').all().map((r) => r.version),
      ['001_init.sql'],
    );
  });

  it('es idempotente: volver a migrar no aplica nada', () => {
    const db = openDb(':memory:');
    assert.deepEqual(migrate(db), []);
  });

  it('actualiza una base anterior a las migraciones sin perder datos', () => {
    const db = new DatabaseSync(':memory:');
    // Esquema "antiguo" creado a mano (sin tabla schema_migrations) con un usuario dentro.
    db.exec(`CREATE TABLE users (id INTEGER PRIMARY KEY, username TEXT NOT NULL UNIQUE COLLATE NOCASE,
      pass_salt TEXT NOT NULL, pass_hash TEXT NOT NULL, character TEXT NOT NULL DEFAULT 'mochi', created_at INTEGER NOT NULL)`);
    db.prepare('INSERT INTO users (username, pass_salt, pass_hash, created_at) VALUES (?,?,?,?)').run('vieja', 's', 'h', 1);
    assert.deepEqual(migrate(db), ['001_init.sql']);
    assert.equal(db.prepare('SELECT username FROM users').get().username, 'vieja');
    assert.ok(tables(db).includes('progress'));
  });

  it('aplica solo las migraciones nuevas, en orden', () => {
    withMigrations({ '001_a.sql': 'CREATE TABLE a (x INTEGER);' }, (dir) => {
      const db = new DatabaseSync(':memory:');
      assert.deepEqual(migrate(db, dir), ['001_a.sql']);
      writeFileSync(new URL('002_b.sql', dir), 'CREATE TABLE b (y INTEGER);');
      writeFileSync(new URL('003_c.sql', dir), 'ALTER TABLE a ADD COLUMN z TEXT;');
      assert.deepEqual(migrate(db, dir), ['002_b.sql', '003_c.sql']);
      assert.deepEqual(tables(db), ['a', 'b', 'schema_migrations']);
    });
  });

  it('una migración que falla se revierte por completo y detiene el arranque', () => {
    withMigrations(
      { '001_ok.sql': 'CREATE TABLE ok (x INTEGER);', '002_mala.sql': 'CREATE TABLE mitad (x INTEGER); CREATE TABLE ok (x INTEGER);' },
      (dir) => {
        const db = new DatabaseSync(':memory:');
        assert.throws(() => migrate(db, dir), /002_mala\.sql/);
        assert.ok(!tables(db).includes('mitad'), 'no debe quedar nada de la migración fallida');
        assert.deepEqual(
          db.prepare('SELECT version FROM schema_migrations').all().map((r) => r.version),
          ['001_ok.sql'],
        );
      },
    );
  });

  it('rechaza nombres de archivo que no siguen el formato NNN_nombre.sql', () => {
    withMigrations({ 'nueva.sql': 'SELECT 1;' }, (dir) => {
      assert.throws(() => migrate(new DatabaseSync(':memory:'), dir), /Nombre de migración no válido/);
    });
  });
});
