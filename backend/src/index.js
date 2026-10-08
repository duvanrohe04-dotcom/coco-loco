import { join } from 'node:path';

import { createApp } from './app.js';

const port = Number(process.env.PORT ?? 8787);
const dataDir = process.env.DATA_DIR ?? join(process.cwd(), 'data');

const server = createApp({
  dbPath: join(dataDir, 'cocoloco.sqlite'),
  maxLevel: Number(process.env.MAX_LEVEL ?? 10),
  trustProxy: process.env.TRUST_PROXY === '1',
  // Una línea por petición en la salida estándar (lo que muestra la pestaña Logs de Coolify).
  // LOG_REQUESTS=0 lo desactiva.
  log: process.env.LOG_REQUESTS === '0' ? null : (line) => console.log(line),
});

server.listen(port, '0.0.0.0', () => {
  console.log(`Coco Loco API escuchando en el puerto ${port} (datos en ${dataDir})`);
  console.log(`TRUST_PROXY=${process.env.TRUST_PROXY === '1' ? 'activo' : 'NO activo (detrás de Coolify debe ser 1)'}`);
});

for (const sig of ['SIGINT', 'SIGTERM']) {
  process.on(sig, () => server.close(() => process.exit(0)));
}
