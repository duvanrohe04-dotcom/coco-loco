#!/bin/sh
# Prueba del autoactualizador contra un "GitHub falso" local (servidor http + paquete .tar.gz).
# Se ejecuta en CI (.github/workflows/ci.yml) y a mano con:  sh deploy/web/test-updater.sh
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
T="$(mktemp -d)"
PORT=8765
SERVER_PID=""
cleanup() { [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null || true; rm -rf "$T"; }
trap cleanup EXIT

fail() { echo "FALLÓ: $*"; exit 1; }
ok() { echo "ok - $*"; }
build_in() { sed -n 's/.*"build" *: *"\([^"]*\)".*/\1/p' "$1" | head -n 1; }

cd "$T"

# Web "instalada" en el servidor (versión aaa1111).
mkdir -p web
echo '<html>VIEJA</html>' > web/index.html
echo '{"build":"aaa1111"}' > web/version.json

# Web "publicada" en GitHub (versión bbb2222), con la misma forma que el tarball de codeload.
mkdir -p pkg/coco-loco-web-dist/site srv/site
echo '<html>NUEVA</html>' > pkg/coco-loco-web-dist/site/index.html
echo '{"build":"bbb2222"}' > pkg/coco-loco-web-dist/site/version.json
tar -czf srv/web.tar.gz -C pkg coco-loco-web-dist
cp pkg/coco-loco-web-dist/site/version.json srv/site/version.json

(cd srv && python3 -m http.server "$PORT" --bind 127.0.0.1 > /dev/null 2>&1) &
SERVER_PID=$!
sleep 1

export RAW_BASE="http://127.0.0.1:$PORT/site"
export TARBALL_URL="http://127.0.0.1:$PORT/web.tar.gz"
export WEB_ROOT="$T/web"
export UPDATE_TMP="$T/tmp"
export ONCE=1

# 1) Hay versión nueva: se actualiza.
sh "$HERE/updater.sh"
grep -q NUEVA web/index.html || fail "no actualizó la web"
[ "$(build_in web/version.json)" = "bbb2222" ] || fail "la versión instalada no cambió"
[ ! -e web.old ] && [ ! -e web.new ] || fail "quedaron carpetas temporales"
ok "actualiza cuando hay versión nueva"

# 2) Misma versión: no toca nada.
echo 'MARCA' > web/marca.txt
sh "$HERE/updater.sh"
[ -f web/marca.txt ] || fail "volvió a descargar sin que hubiera versión nueva"
ok "no hace nada si ya está al día"

# 3) El paquete no coincide con la versión anunciada (GitHub publicando a medias): no cambia.
echo '{"build":"ccc3333"}' > srv/site/version.json
sh "$HERE/updater.sh"
[ "$(build_in web/version.json)" = "bbb2222" ] || fail "instaló un paquete que no coincidía"
[ -f web/marca.txt ] || fail "reemplazó la web con un paquete que no coincidía"
ok "ignora un paquete que no coincide con lo anunciado"

# 4) Paquete dañado: se conserva la web actual.
echo '{"build":"ddd4444"}' > srv/site/version.json
echo 'esto no es un tar.gz' > srv/web.tar.gz
sh "$HERE/updater.sh"
[ -f web/marca.txt ] || fail "perdió la web actual con un paquete dañado"
ok "conserva la web actual si el paquete está dañado"

# 5) Sin conexión a GitHub: se conserva la web actual y no falla.
kill "$SERVER_PID" 2>/dev/null || true
SERVER_PID=""
sleep 1
sh "$HERE/updater.sh"
[ -f web/marca.txt ] || fail "perdió la web actual sin conexión"
ok "conserva la web actual si GitHub no responde"

echo "Todo bien."
