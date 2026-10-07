// Copia de seguridad consistente de la base de datos (segura aunque el servidor esté en uso).
//   node src/backup.js          -> DATA_DIR/backups/cocoloco-AAAA-MM-DD.sqlite
// Conserva las últimas BACKUP_KEEP copias (7 por defecto).
import { existsSync, mkdirSync, readdirSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';

const dataDir = process.env.DATA_DIR ?? join(process.cwd(), 'data');
const keep = Number(process.env.BACKUP_KEEP ?? 7);
const source = join(dataDir, 'cocoloco.sqlite');
const dir = join(dataDir, 'backups');

if (!existsSync(source)) {
  console.error(`No existe la base de datos: ${source}`);
  process.exit(1);
}
mkdirSync(dir, { recursive: true });

const target = join(dir, `cocoloco-${new Date().toISOString().slice(0, 10)}.sqlite`);
rmSync(target, { force: true }); // si se ejecuta dos veces el mismo día, se reemplaza

const db = new DatabaseSync(source, { readOnly: true });
try {
  // VACUUM INTO genera una copia íntegra y compacta sin bloquear a los demás.
  db.prepare('VACUUM INTO ?').run(target);
} finally {
  db.close();
}

const old = readdirSync(dir)
  .filter((f) => /^cocoloco-\d{4}-\d{2}-\d{2}\.sqlite$/.test(f))
  .sort()
  .reverse()
  .slice(keep);
for (const f of old) rmSync(join(dir, f));

console.log(`Copia creada: ${target} (se conservan ${keep})`);
