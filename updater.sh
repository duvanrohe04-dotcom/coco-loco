#!/bin/sh
# Autoactualizador de la web (corre dentro del contenedor, junto a nginx).
#
# Cada UPDATE_INTERVAL segundos mira qué versión hay publicada en la rama `web-dist` de GitHub y, si es
# distinta de la que está sirviendo, descarga la web nueva y la cambia de golpe. Así subir un cambio a
# `main` basta: NO hace falta pulsar Redeploy en Coolify, y un redeploy hecho demasiado pronto (antes de
# que GitHub termine de compilar) deja de ser un problema: en pocos minutos el servidor se pone al día solo.
#
# Seguro por diseño:
#  - Solo reemplaza la web si el paquete descargado está completo y coincide con la versión anunciada.
#  - Si GitHub no responde o algo falla, la web actual sigue sirviéndose sin tocarla.
#  - El cambio es un renombrado de carpeta (atómico): nunca hay una web a medias.
#
# Variables (todas opcionales): UPDATE_REPO, UPDATE_BRANCH, UPDATE_INTERVAL, SELF_UPDATE=0 para apagarlo.
# Para pruebas: RAW_BASE, TARBALL_URL, WEB_ROOT, UPDATE_TMP y ONCE=1 (una comprobación y salir).

REPO="${UPDATE_REPO:-duvanrohe04-dotcom/coco-loco}"
BRANCH="${UPDATE_BRANCH:-web-dist}"
WEB="${WEB_ROOT:-/usr/share/nginx/html}"
INTERVAL="${UPDATE_INTERVAL:-120}"
RAW="${RAW_BASE:-https://raw.githubusercontent.com/$REPO/$BRANCH/site}"
TARBALL="${TARBALL_URL:-https://codeload.github.com/$REPO/tar.gz/refs/heads/$BRANCH}"
TMP="${UPDATE_TMP:-/tmp/web-update}"

log() { echo "[updater] $*"; }

# Lee el campo "build" de un version.json que llega por la entrada estándar.
build_of() { sed -n 's/.*"build" *: *"\([^"]*\)".*/\1/p' | head -n 1; }

check_once() {
  remote="$(curl -fsS --max-time 20 "$RAW/version.json?t=$(date +%s)" 2>/dev/null | build_of)"
  if [ -z "$remote" ]; then
    log "no pude leer la versión publicada (se reintenta luego)"
    return 0
  fi
  current="$(build_of < "$WEB/version.json" 2>/dev/null)"
  [ "$remote" = "$current" ] && return 0

  log "versión nueva: $current -> $remote; descargando..."
  rm -rf "$TMP"
  mkdir -p "$TMP/x"
  if ! curl -fsSL --max-time 180 "$TARBALL" -o "$TMP/web.tar.gz"; then
    log "falló la descarga (se reintenta luego)"
    rm -rf "$TMP"
    return 0
  fi
  if ! tar -xzf "$TMP/web.tar.gz" -C "$TMP/x"; then
    log "el paquete está dañado (se reintenta luego)"
    rm -rf "$TMP"
    return 0
  fi
  site="$(ls -d "$TMP"/x/*/site 2>/dev/null | head -n 1)"
  if [ ! -f "$site/index.html" ] || [ ! -f "$site/version.json" ]; then
    log "el paquete no trae una web completa (se reintenta luego)"
    rm -rf "$TMP"
    return 0
  fi
  got="$(build_of < "$site/version.json")"
  if [ "$got" != "$remote" ]; then
    # GitHub estaba publicando justo en ese momento: se espera a la siguiente vuelta.
    log "el paquete ($got) no coincide con la versión anunciada ($remote); se reintenta luego"
    rm -rf "$TMP"
    return 0
  fi

  rm -rf "$WEB.new" "$WEB.old"
  if cp -r "$site" "$WEB.new" && mv "$WEB" "$WEB.old"; then
    if mv "$WEB.new" "$WEB"; then
      log "web actualizada a $remote"
    else
      mv "$WEB.old" "$WEB" # si algo falla, se vuelve a la anterior
      log "no se pudo activar la versión nueva; se conserva la actual"
    fi
  else
    log "no se pudo preparar la versión nueva; se conserva la actual"
  fi
  rm -rf "$WEB.new" "$WEB.old" "$TMP"
  return 0
}

if [ "$ONCE" = "1" ]; then
  check_once
  exit 0
fi

sleep 15 # deja que nginx arranque primero
log "vigilando $REPO ($BRANCH) cada ${INTERVAL}s"
while true; do
  check_once
  sleep "$INTERVAL"
done
