// Aplica las migraciones pendientes y muestra el estado:  npm run migrate
import { join } from 'node:path';

import { openDb } from './db.js';

const dataDir = process.env.DATA_DIR ?? join(process.cwd(), 'data');
const db = openDb(join(dataDir, 'cocoloco.sqlite'));
const rows = db.prepare('SELECT version, applied_at FROM schema_migrations ORDER BY version').all();
for (const r of rows) console.log(`✔ ${r.version}  (${new Date(r.applied_at).toISOString()})`);
console.log(`${rows.length} migración(es) aplicada(s). Base de datos al día.`);
db.close();
