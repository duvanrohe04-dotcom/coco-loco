# Imagen LIGERA de la web: nginx + los archivos ya compilados (carpeta site/) + un autoactualizador.
# No compila Flutter, así que funciona en servidores con poca memoria y despliega en segundos.
# Este archivo se copia a la rama `web-dist` junto con nginx.conf, los scripts y site/ (ver .github/workflows/web.yml).
FROM nginx:1.27-alpine

# curl lo usa el autoactualizador para consultar GitHub.
RUN apk add --no-cache curl

COPY nginx.conf /etc/nginx/conf.d/default.conf
# Copia de la web con la que se construyó la imagen (sirve de base y de respaldo si GitHub no responde).
COPY site /usr/share/nginx/html

# Autoactualizador: mira la rama `web-dist` y se pone al día solo, sin pulsar Redeploy.
COPY updater.sh /usr/local/bin/web-updater.sh
COPY 40-self-update.sh /docker-entrypoint.d/40-self-update.sh
RUN chmod +x /usr/local/bin/web-updater.sh /docker-entrypoint.d/40-self-update.sh

EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD wget -qO- http://127.0.0.1/healthz || exit 1
