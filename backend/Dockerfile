FROM node:24-alpine

ENV NODE_ENV=production \
    PORT=8787 \
    DATA_DIR=/data

# su-exec: arrancar como root solo para arreglar permisos del volumen y luego bajar a "node".
RUN apk add --no-cache su-exec

WORKDIR /app
COPY package.json ./
COPY src ./src
COPY migrations ./migrations
RUN mkdir -p /data && chown -R node:node /app /data

# La base de datos vive en /data: monta ahí un volumen persistente.
# Los volúmenes nuevos (Coolify, Docker) suelen ser de root, por eso se corrige al arrancar.
VOLUME ["/data"]
EXPOSE 8787

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s CMD wget -qO- http://127.0.0.1:${PORT}/health || exit 1

CMD ["sh", "-c", "chown -R node:node \"$DATA_DIR\" && exec su-exec node node --no-warnings src/index.js"]
