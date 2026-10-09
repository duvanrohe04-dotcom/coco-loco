#!/bin/sh
# La imagen oficial de nginx ejecuta los scripts de /docker-entrypoint.d/ antes de arrancar nginx.
# Este lanza el autoactualizador en segundo plano (y no bloquea el arranque).
# SELF_UPDATE=0 en las variables de Coolify lo desactiva.
if [ "${SELF_UPDATE:-1}" = "1" ]; then
  nohup /usr/local/bin/web-updater.sh > /proc/1/fd/1 2>&1 &
fi
exit 0
