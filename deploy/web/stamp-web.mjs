// Sella una compilación web de Flutter para que NINGÚN navegador pueda quedarse con una versión vieja.
//
// El problema: Flutter genera siempre `main.dart.js` (el juego entero) con el mismo nombre. Si el
// navegador lo guarda en su caché (nginx lo servía con "max-age" de 7 días), sigue ejecutando la versión
// vieja aunque el servidor ya tenga la nueva: el `index.html` y `flutter_bootstrap.js` llegan frescos,
// pero apuntan a un archivo cuyo nombre no cambió. Ni un service worker ni borrar cachés desde la página
// lo arreglan, porque esa caché es la HTTP del navegador.
//
// La solución: cada compilación renombra el juego a `main.dart.<versión>.js` y `flutter_bootstrap.js`
// (que se sirve siempre sin caché) apunta a ese nombre nuevo. Un nombre distinto = el navegador tiene que
// descargarlo, pase lo que pase con su caché. No se toca ningún dato del jugador.
//
// Uso:  node deploy/web/stamp-web.mjs <carpeta build/web> <build> <numero>
import { existsSync, readFileSync, renameSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const [dir, build, run] = process.argv.slice(2);
if (!dir || !build || !run) {
  console.error('Uso: node stamp-web.mjs <carpeta build/web> <build> <numero>');
  process.exit(2);
}

const fail = (msg) => {
  console.error(`ERROR: ${msg}`);
  process.exit(1);
};

const bootstrapPath = join(dir, 'flutter_bootstrap.js');
const oldJs = join(dir, 'main.dart.js');
if (!existsSync(bootstrapPath)) fail(`no existe ${bootstrapPath}`);
if (!existsSync(oldJs)) fail(`no existe ${oldJs}`);

const name = `main.dart.${build}-${run}.js`;
const bootstrap = readFileSync(bootstrapPath, 'utf8');

// Si Flutter cambia el formato de esta configuración, esto falla a propósito (en vez de publicar una web
// sin sellar que volvería a quedarse en la caché de los navegadores).
const pattern = /"mainJsPath"\s*:\s*"main\.dart\.js"/g;
const count = (bootstrap.match(pattern) ?? []).length;
if (count < 1) fail('flutter_bootstrap.js no tiene "mainJsPath":"main.dart.js"; Flutter cambió su formato y hay que adaptar este script');

const patched = bootstrap.replace(pattern, `"mainJsPath":"${name}"`);
// (flutter.js lleva "main.dart.js" como valor por defecto interno, que solo se usa si la configuración no
// trae mainJsPath; la nuestra sí. Lo que importa es que la configuración apunte al nombre sellado.)
if (new RegExp(pattern.source).test(patched)) fail('la configuración sigue apuntando a main.dart.js sin sellar');
if (!patched.includes(`"mainJsPath":"${name}"`)) fail('no se pudo escribir el nombre sellado en la configuración');

renameSync(oldJs, join(dir, name));
writeFileSync(bootstrapPath, patched);

// version.json: lo lee la página para saber si hay una versión nueva (siempre sin caché).
writeFileSync(
  join(dir, 'version.json'),
  JSON.stringify({ app_name: 'coco_loco', version: '1.0.0', build_number: String(run), build: String(build), main: name }) + '\n',
);

// Comprobación final: lo que se va a publicar es coherente.
if (!existsSync(join(dir, name))) fail(`no se creó ${name}`);
if (existsSync(oldJs)) fail('main.dart.js sigue existiendo con su nombre original');
if (!readFileSync(bootstrapPath, 'utf8').includes(name)) fail('flutter_bootstrap.js no apunta al archivo sellado');

console.log(`Sellado: main.dart.js -> ${name} (flutter_bootstrap.js actualizado)`);
