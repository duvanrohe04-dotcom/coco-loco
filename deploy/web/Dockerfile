# Imagen LIGERA de la web: solo nginx + los archivos ya compilados (carpeta site/).
# No compila Flutter, así que funciona en servidores con poca memoria y despliega en segundos.
# Este archivo se copia a la rama `web-dist` junto con nginx.conf y site/ (ver .github/workflows/web.yml).
FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY site /usr/share/nginx/html

EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD wget -qO- http://127.0.0.1/healthz || exit 1
