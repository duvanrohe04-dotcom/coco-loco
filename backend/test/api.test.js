import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';

import { createApp } from '../src/app.js';

let server;
let base;

before(async () => {
  server = createApp({ dbPath: ':memory:', authLimit: 1000 });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  base = `http://127.0.0.1:${server.address().port}`;
});

after(() => new Promise((r) => server.close(r)));

async function call(method, path, { body, token } = {}) {
  const res = await fetch(base + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body === undefined ? undefined : typeof body === 'string' ? body : JSON.stringify(body),
  });
  return { status: res.status, json: await res.json().catch(() => null) };
}

const register = (username, password = 'secreto123') => call('POST', '/api/register', { body: { username, password } });

describe('cuentas', () => {
  it('registra, devuelve token y perfil vacío', async () => {
    const r = await register('ana_01');
    assert.equal(r.status, 201);
    assert.ok(r.json.token.length >= 40);
    assert.deepEqual(r.json.profile, { username: 'ana_01', character: 'mochi', stars: {}, streaks: {} });
  });

  it('rechaza usuario repetido sin distinguir mayúsculas', async () => {
    await register('Luis');
    const r = await register('luis');
    assert.equal(r.status, 409);
  });

  it('valida usuario y contraseña', async () => {
    assert.equal((await register('ab')).status, 400);
    assert.equal((await register('con espacio')).status, 400);
    assert.equal((await register('valido1', 'corta')).status, 400);
    assert.equal((await register('valido2', 'x'.repeat(73))).status, 400);
  });

  it('login correcto e incorrecto', async () => {
    await register('maria');
    const ok = await call('POST', '/api/login', { body: { username: 'MARIA', password: 'secreto123' } });
    assert.equal(ok.status, 200);
    assert.ok(ok.json.token);
    const bad = await call('POST', '/api/login', { body: { username: 'maria', password: 'otra-clave-1' } });
    const ghost = await call('POST', '/api/login', { body: { username: 'noexiste', password: 'secreto123' } });
    assert.equal(bad.status, 401);
    assert.equal(ghost.status, 401);
    assert.equal(bad.json.error, ghost.json.error); // no revela si el usuario existe
  });

  it('logout invalida el token', async () => {
    const { json } = await register('pepe');
    assert.equal((await call('GET', '/api/me', { token: json.token })).status, 200);
    assert.equal((await call('POST', '/api/logout', { token: json.token })).status, 200);
    assert.equal((await call('GET', '/api/me', { token: json.token })).status, 401);
  });

  it('exige token válido', async () => {
    assert.equal((await call('GET', '/api/me')).status, 401);
    assert.equal((await call('GET', '/api/me', { token: 'x'.repeat(43) })).status, 401);
  });

  it('borrar cuenta elimina datos y sesión', async () => {
    const { json } = await register('borrame');
    assert.equal((await call('DELETE', '/api/me', { token: json.token })).status, 200);
    assert.equal((await call('GET', '/api/me', { token: json.token })).status, 401);
    assert.equal((await call('POST', '/api/login', { body: { username: 'borrame', password: 'secreto123' } })).status, 401);
  });
});

describe('perfil y progreso', () => {
  it('cambia de personaje y rechaza uno inválido', async () => {
    const { json } = await register('car1');
    const ok = await call('PUT', '/api/me', { token: json.token, body: { character: 'dino' } });
    assert.equal(ok.json.character, 'dino');
    assert.equal((await call('PUT', '/api/me', { token: json.token, body: { character: 'hacker' } })).status, 400);
  });

  it('guarda el mejor resultado y nunca lo baja', async () => {
    const { json } = await register('prog1');
    await call('PUT', '/api/progress', { token: json.token, body: { level: 1, stars: 2, streak: 9 } });
    const r = await call('PUT', '/api/progress', { token: json.token, body: { level: 1, stars: 1, streak: 4 } });
    assert.equal(r.json.stars[1], 2);
    assert.equal(r.json.streaks[1], 9);
    const up = await call('PUT', '/api/progress', { token: json.token, body: { level: 1, stars: 3, streak: 12 } });
    assert.equal(up.json.stars[1], 3);
    assert.equal(up.json.streaks[1], 12);
  });

  it('rechaza progreso fuera de rango', async () => {
    const { json } = await register('prog2');
    for (const body of [
      { level: 0, stars: 1 },
      { level: 11, stars: 1 },
      { level: 1, stars: 4 },
      { level: 1, stars: -1 },
      { level: 1, stars: 1.5 },
      { level: 1, stars: '3' },
      { level: 1, stars: 1, streak: 999999 },
    ]) {
      assert.equal((await call('PUT', '/api/progress', { token: json.token, body })).status, 400, JSON.stringify(body));
    }
  });

  it('fusiona el progreso local de golpe', async () => {
    const { json } = await register('merge1');
    const r = await call('POST', '/api/progress/merge', { token: json.token, body: { stars: { 1: 3, 2: 1 }, streaks: { 1: 7 } } });
    assert.deepEqual(r.json.stars, { 1: 3, 2: 1 });
    assert.equal(r.json.streaks[1], 7);
    const bad = await call('POST', '/api/progress/merge', { token: json.token, body: { stars: { 1: 1, 99: 1 } } });
    assert.equal(bad.status, 400);
  });
});

describe('ranking y robustez', () => {
  it('ordena por estrellas totales', async () => {
    const a = await register('rankA');
    const b = await register('rankB');
    await call('PUT', '/api/progress', { token: a.json.token, body: { level: 1, stars: 3 } });
    await call('PUT', '/api/progress', { token: b.json.token, body: { level: 1, stars: 3 } });
    await call('PUT', '/api/progress', { token: b.json.token, body: { level: 2, stars: 2 } });
    const { json } = await call('GET', '/api/leaderboard');
    const names = json.players.map((p) => p.username);
    assert.ok(names.indexOf('rankB') < names.indexOf('rankA'));
    assert.equal(json.players.find((p) => p.username === 'rankB').stars, 5);
    assert.ok(!('pass_hash' in json.players[0]));
  });

  it('maneja JSON roto, cuerpo enorme, rutas y métodos', async () => {
    assert.equal((await call('POST', '/api/login', { body: '{no es json' })).status, 400);
    assert.equal((await call('POST', '/api/login', { body: '[1,2]' })).status, 400);
    assert.equal((await call('POST', '/api/register', { body: JSON.stringify({ username: 'x'.repeat(20000) }) })).status, 413);
    assert.equal((await call('GET', '/api/nada')).status, 404);
    assert.equal((await call('GET', '/api/login')).status, 405);
    assert.equal((await call('GET', '/health')).json.ok, true);
  });

  it('responde al preflight CORS', async () => {
    const res = await fetch(`${base}/api/me`, { method: 'OPTIONS' });
    assert.equal(res.status, 204);
    assert.equal(res.headers.get('access-control-allow-origin'), '*');
  });

  it('limita intentos de autenticación por IP', async () => {
    const limited = createApp({ dbPath: ':memory:', authLimit: 3 });
    await new Promise((r) => limited.listen(0, '127.0.0.1', r));
    const url = `http://127.0.0.1:${limited.address().port}/api/login`;
    const statuses = [];
    for (let i = 0; i < 5; i++) {
      const res = await fetch(url, { method: 'POST', body: JSON.stringify({ username: 'nadie', password: 'secreto123' }) });
      statuses.push(res.status);
    }
    await new Promise((r) => limited.close(r));
    assert.deepEqual(statuses, [401, 401, 401, 429, 429]);
  });
});
