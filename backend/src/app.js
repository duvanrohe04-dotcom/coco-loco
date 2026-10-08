import crypto from 'node:crypto';
import http from 'node:http';
import { promisify } from 'node:util';

import { openDb } from './db.js';

const scrypt = promisify(crypto.scrypt);

const CHARACTERS = new Set(['mochi', 'dino', 'robot']);
const USERNAME_RE = /^[A-Za-z0-9_]{3,16}$/;
const MAX_BODY = 10 * 1024;
const SESSION_DAYS = 90;
const DAY_MS = 86_400_000;

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

const sha256 = (s) => crypto.createHash('sha256').update(s).digest('hex');

async function hashPassword(password, salt) {
  return (await scrypt(password, salt, 64)).toString('hex');
}

/**
 * Crea el servidor HTTP de la API.
 * @param {object} opts
 * @param {string} opts.dbPath          ruta del archivo SQLite (o ':memory:')
 * @param {number} [opts.maxLevel=20]   niveles válidos para guardar progreso
 * @param {boolean} [opts.trustProxy]   leer la IP de X-Forwarded-For (detrás de un proxy)
 * @param {number} [opts.authLimit=15]  intentos de login/registro por IP cada 10 min
 * @param {(line: string) => void} [opts.log]  registro de accesos (una línea por petición); null = silencio.
 *        Solo se anota método, ruta (sin query), estado, duración e IP: nunca cuerpos ni cabeceras.
 */
export function createApp({ dbPath, maxLevel = 20, trustProxy = false, authLimit = 15, log = null }) {
  const db = openDb(dbPath);

  const q = {
    userByName: db.prepare('SELECT * FROM users WHERE username = ?'),
    insertUser: db.prepare('INSERT INTO users (username, pass_salt, pass_hash, character, created_at) VALUES (?, ?, ?, ?, ?)'),
    insertSession: db.prepare('INSERT INTO sessions (token_hash, user_id, expires_at) VALUES (?, ?, ?)'),
    sessionUser: db.prepare(
      'SELECT u.* FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.token_hash = ? AND s.expires_at > ?',
    ),
    deleteSession: db.prepare('DELETE FROM sessions WHERE token_hash = ?'),
    deleteExpired: db.prepare('DELETE FROM sessions WHERE expires_at <= ?'),
    setCharacter: db.prepare('UPDATE users SET character = ? WHERE id = ?'),
    progressOf: db.prepare('SELECT level, stars, streak FROM progress WHERE user_id = ?'),
    upsertProgress: db.prepare(`
      INSERT INTO progress (user_id, level, stars, streak) VALUES (?, ?, ?, ?)
      ON CONFLICT (user_id, level) DO UPDATE SET
        stars = MAX(stars, excluded.stars),
        streak = MAX(streak, excluded.streak)`),
    deleteUser: db.prepare('DELETE FROM users WHERE id = ?'),
    leaderboard: db.prepare(`
      SELECT u.username, u.character, SUM(p.stars) AS stars, MAX(p.streak) AS bestStreak
      FROM users u JOIN progress p ON p.user_id = u.id
      GROUP BY u.id HAVING SUM(p.stars) > 0
      ORDER BY stars DESC, bestStreak DESC, u.id ASC
      LIMIT 20`),
  };

  // Hash de relleno para que "usuario inexistente" tarde lo mismo que "clave incorrecta".
  const dummySalt = crypto.randomBytes(16).toString('hex');
  const dummyHash = hashPassword('dummy-password', dummySalt);

  const hits = new Map(); // ip -> { count, reset }
  function rateLimit(ip) {
    const now = Date.now();
    const e = hits.get(ip);
    if (!e || e.reset <= now) {
      hits.set(ip, { count: 1, reset: now + 10 * 60_000 });
      return;
    }
    if (++e.count > authLimit) throw new HttpError(429, 'Demasiados intentos. Espera unos minutos.');
  }
  const sweeper = setInterval(() => {
    const now = Date.now();
    for (const [ip, e] of hits) if (e.reset <= now) hits.delete(ip);
    q.deleteExpired.run(now);
  }, 10 * 60_000);
  sweeper.unref();

  const clientIp = (req) =>
    (trustProxy && String(req.headers['x-forwarded-for'] ?? '').split(',')[0].trim()) || req.socket.remoteAddress || 'unknown';

  async function readJson(req) {
    const chunks = [];
    let size = 0;
    for await (const c of req) {
      size += c.length;
      if (size > MAX_BODY) throw new HttpError(413, 'Solicitud demasiado grande');
      chunks.push(c);
    }
    if (size === 0) return {};
    try {
      const v = JSON.parse(Buffer.concat(chunks).toString('utf8'));
      if (v === null || typeof v !== 'object' || Array.isArray(v)) throw new Error();
      return v;
    } catch {
      throw new HttpError(400, 'JSON inválido');
    }
  }

  function authUser(req) {
    const m = /^Bearer ([A-Za-z0-9_-]{20,})$/.exec(req.headers.authorization ?? '');
    const user = m && q.sessionUser.get(sha256(m[1]), Date.now());
    if (!user) throw new HttpError(401, 'Sesión no válida. Inicia sesión de nuevo.');
    return { user, tokenHash: sha256(m[1]) };
  }

  function issueSession(userId) {
    const token = crypto.randomBytes(32).toString('base64url');
    q.insertSession.run(sha256(token), userId, Date.now() + SESSION_DAYS * DAY_MS);
    return token;
  }

  function profileOf(user) {
    const stars = {};
    const streaks = {};
    for (const r of q.progressOf.all(user.id)) {
      stars[r.level] = r.stars;
      streaks[r.level] = r.streak;
    }
    return { username: user.username, character: user.character, stars, streaks };
  }

  function validateCredentials(body) {
    const { username, password } = body;
    if (typeof username !== 'string' || !USERNAME_RE.test(username)) {
      throw new HttpError(400, 'El usuario debe tener 3 a 16 letras, números o _');
    }
    if (typeof password !== 'string' || password.length < 8 || password.length > 72) {
      throw new HttpError(400, 'La contraseña debe tener entre 8 y 72 caracteres');
    }
    return { username, password };
  }

  const isInt = (v, min, max) => Number.isInteger(v) && v >= min && v <= max;

  const routes = {
    'GET /health': () => ({ ok: true }),

    'POST /api/register': async (req) => {
      rateLimit(clientIp(req));
      const { username, password } = validateCredentials(await readJson(req));
      const salt = crypto.randomBytes(16).toString('hex');
      const hash = await hashPassword(password, salt);
      let id;
      try {
        id = q.insertUser.run(username, salt, hash, 'mochi', Date.now()).lastInsertRowid;
      } catch (e) {
        if (String(e.message).includes('UNIQUE')) throw new HttpError(409, 'Ese usuario ya existe');
        throw e;
      }
      const user = q.userByName.get(username);
      return { status: 201, body: { token: issueSession(Number(id)), profile: profileOf(user) } };
    },

    'POST /api/login': async (req) => {
      rateLimit(clientIp(req));
      const { username, password } = validateCredentials(await readJson(req));
      const user = q.userByName.get(username);
      const expected = Buffer.from(user ? user.pass_hash : await dummyHash, 'hex');
      const actual = Buffer.from(await hashPassword(password, user ? user.pass_salt : dummySalt), 'hex');
      if (!user || !crypto.timingSafeEqual(expected, actual)) throw new HttpError(401, 'Usuario o contraseña incorrectos');
      return { token: issueSession(user.id), profile: profileOf(user) };
    },

    'POST /api/logout': (req) => {
      const { tokenHash } = authUser(req);
      q.deleteSession.run(tokenHash);
      return { ok: true };
    },

    'GET /api/me': (req) => profileOf(authUser(req).user),

    'PUT /api/me': async (req) => {
      const { user } = authUser(req);
      const { character } = await readJson(req);
      if (!CHARACTERS.has(character)) throw new HttpError(400, 'Personaje no válido');
      q.setCharacter.run(character, user.id);
      return profileOf({ ...user, character });
    },

    // Guarda el mejor resultado de un nivel (nunca baja estrellas ni racha ya logradas).
    'PUT /api/progress': async (req) => {
      const { user } = authUser(req);
      const { level, stars, streak = 0 } = await readJson(req);
      if (!isInt(level, 1, maxLevel) || !isInt(stars, 0, 3) || !isInt(streak, 0, 10_000)) {
        throw new HttpError(400, 'Datos de progreso no válidos');
      }
      q.upsertProgress.run(user.id, level, stars, streak);
      return profileOf(user);
    },

    // Fusiona de una vez el progreso local del dispositivo (al iniciar sesión).
    'POST /api/progress/merge': async (req) => {
      const { user } = authUser(req);
      const { stars = {}, streaks = {} } = await readJson(req);
      if (typeof stars !== 'object' || typeof streaks !== 'object' || stars === null || streaks === null) {
        throw new HttpError(400, 'Datos de progreso no válidos');
      }
      const levels = new Set([...Object.keys(stars), ...Object.keys(streaks)].map(Number));
      db.exec('BEGIN');
      try {
        for (const level of levels) {
          const s = stars[level] ?? 0;
          const k = streaks[level] ?? 0;
          if (!isInt(level, 1, maxLevel) || !isInt(s, 0, 3) || !isInt(k, 0, 10_000)) {
            throw new HttpError(400, 'Datos de progreso no válidos');
          }
          q.upsertProgress.run(user.id, level, s, k);
        }
        db.exec('COMMIT');
      } catch (e) {
        db.exec('ROLLBACK');
        throw e;
      }
      return profileOf(user);
    },

    'GET /api/leaderboard': () => ({ players: q.leaderboard.all().map((r) => ({ ...r, stars: Number(r.stars), bestStreak: Number(r.bestStreak) })) }),

    'DELETE /api/me': (req) => {
      q.deleteUser.run(authUser(req).user.id);
      return { ok: true };
    },
  };

  const server = http.createServer(async (req, res) => {
    const started = process.hrtime.bigint();
    const logPath = (req.url ?? '/').split('?')[0];
    // /health se omite: el health check de Coolify lo consulta cada pocos segundos y llenaría el registro.
    if (log && logPath !== '/health') {
      res.on('finish', () => {
        const ms = Number((process.hrtime.bigint() - started) / 1_000_000n);
        log(`${req.method} ${logPath} ${res.statusCode} ${ms}ms ip=${clientIp(req)}`);
      });
    }

    const send = (status, body) => {
      const data = JSON.stringify(body);
      res.writeHead(status, {
        'Content-Type': 'application/json; charset=utf-8',
        'Content-Length': Buffer.byteLength(data),
        'Cache-Control': 'no-store',
        'X-Content-Type-Options': 'nosniff',
        // Auth por cabecera Bearer (sin cookies), así que abrir CORS no expone sesiones.
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Authorization, Content-Type',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      });
      res.end(data);
    };

    try {
      if (req.method === 'OPTIONS') {
        res.writeHead(204, {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Headers': 'Authorization, Content-Type',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Max-Age': '86400',
        });
        return res.end();
      }
      const path = new URL(req.url, 'http://x').pathname.replace(/\/+$/, '') || '/';
      const handler = routes[`${req.method} ${path}`];
      if (!handler) {
        const known = Object.keys(routes).some((k) => k.endsWith(` ${path}`));
        throw new HttpError(known ? 405 : 404, known ? 'Método no permitido' : 'No encontrado');
      }
      const out = await handler(req);
      if (out && out.status && out.body) send(out.status, out.body);
      else send(200, out);
    } catch (e) {
      if (e instanceof HttpError) return send(e.status, { error: e.message });
      console.error(e);
      send(500, { error: 'Error interno del servidor' });
    }
  });

  server.on('close', () => {
    clearInterval(sweeper);
    db.close();
  });
  return server;
}
