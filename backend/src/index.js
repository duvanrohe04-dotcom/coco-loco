import { join } from 'node:path';

import { createApp } from './app.js';

const port = Number(process.env.PORT ?? 8787);
const dataDir = process.env.DATA_DIR ?? join(process.cwd(), 'data');

const server = createApp({
  dbPath: join(dataDir, 'cocoloco.sqlite'),
  maxLevel: Number(process.env.MAX_LEVEL ?? 10),
  trustProxy: process.env.TRUST_PROXY === '1',
});

server.listen(port, '0.0.0.0', () => console.log(`Coco Loco API escuchando en el puerto ${port} (datos en ${dataDir})`));

for (const sig of ['SIGINT', 'SIGTERM']) {
  process.on(sig, () => server.close(() => process.exit(0)));
}
