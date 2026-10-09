// Prueba de stamp-web.mjs:  node deploy/web/test-stamp.mjs   (se ejecuta en CI)
import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const script = join(dirname(fileURLToPath(import.meta.url)), 'stamp-web.mjs');
const BOOT =
  'async loadEntrypoint(e){let{entrypointUrl:s=m("main.dart.js")}=e||{}} ' +
  'let a=e.mainJsPath??"main.dart.js"; ' +
  '_flutter.buildConfig={"engineRevision":"x","builds":[{"compileTarget":"dart2js","renderer":"canvaskit","mainJsPath":"main.dart.js"}]};';

function fakeBuild(bootstrap = BOOT) {
  const dir = mkdtempSync(join(tmpdir(), 'stamp-'));
  writeFileSync(join(dir, 'main.dart.js'), '// el juego');
  writeFileSync(join(dir, 'flutter_bootstrap.js'), bootstrap);
  writeFileSync(join(dir, 'index.html'), '<html></html>');
  return dir;
}

// 1) Sella: renombra el juego, apunta el bootstrap y escribe version.json.
{
  const dir = fakeBuild();
  execFileSync('node', [script, dir, 'abc1234', '42'], { stdio: 'pipe' });
  const name = 'main.dart.abc1234-42.js';
  assert.ok(existsSync(join(dir, name)), 'existe el juego con nombre sellado');
  assert.ok(!existsSync(join(dir, 'main.dart.js')), 'ya no existe main.dart.js');
  assert.equal(readFileSync(join(dir, name), 'utf8'), '// el juego', 'el contenido no cambia');
  const boot = readFileSync(join(dir, 'flutter_bootstrap.js'), 'utf8');
  assert.ok(boot.includes(`"mainJsPath":"${name}"`), 'el bootstrap apunta al nombre sellado');
  assert.ok(!boot.includes('"mainJsPath":"main.dart.js"'), 'no queda la configuración sin sellar');
  const v = JSON.parse(readFileSync(join(dir, 'version.json'), 'utf8'));
  assert.deepEqual([v.build, v.build_number, v.main], ['abc1234', '42', name]);
  rmSync(dir, { recursive: true });
  console.log('ok - sella el juego y el bootstrap');
}

// 2) Dos compilaciones distintas dan nombres distintos (la caché no puede reutilizar la anterior).
{
  const a = fakeBuild();
  const b = fakeBuild();
  execFileSync('node', [script, a, 'aaaaaaa', '1'], { stdio: 'pipe' });
  execFileSync('node', [script, b, 'bbbbbbb', '2'], { stdio: 'pipe' });
  const na = JSON.parse(readFileSync(join(a, 'version.json'), 'utf8')).main;
  const nb = JSON.parse(readFileSync(join(b, 'version.json'), 'utf8')).main;
  assert.notEqual(na, nb);
  rmSync(a, { recursive: true });
  rmSync(b, { recursive: true });
  console.log('ok - cada compilación tiene un nombre distinto');
}

// 3) Si Flutter cambia el formato, FALLA en vez de publicar sin sellar.
{
  const dir = fakeBuild('_flutter.buildConfig={"builds":[{"otro":"formato"}]};');
  const r = spawnSync('node', [script, dir, 'abc1234', '42'], { encoding: 'utf8' });
  assert.notEqual(r.status, 0, 'debe fallar');
  assert.match(r.stderr, /mainJsPath/);
  assert.ok(existsSync(join(dir, 'main.dart.js')), 'no toca los archivos si falla');
  rmSync(dir, { recursive: true });
  console.log('ok - falla (sin tocar nada) si Flutter cambia su formato');
}

// 4) Sin los archivos esperados, también falla.
{
  const dir = mkdtempSync(join(tmpdir(), 'stamp-'));
  const r = spawnSync('node', [script, dir, 'abc1234', '42'], { encoding: 'utf8' });
  assert.notEqual(r.status, 0);
  rmSync(dir, { recursive: true });
  console.log('ok - falla si la carpeta no es una compilación');
}

console.log('Todo bien.');
