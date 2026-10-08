# Versión WEB del juego (para iPhone, Android y PC desde el navegador).
# En Coolify es una aplicación aparte del backend (ver DEPLOY.md):
#   Base Directory: /   ·   Dockerfile Location: /Dockerfile   ·   Ports Exposes: 80

# ---- Etapa 1: compilar Flutter web ------------------------------------------
FROM debian:bookworm-slim AS build

ARG FLUTTER_VERSION=3.47.6
# URL pública del backend. Se sobrescribe en Coolify con la variable de build API_URL.
ARG API_URL=https://cocoloco.sbs.mom
ENV PUB_CACHE=/root/.pub-cache

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils \
    && rm -rf /var/lib/apt/lists/*

# SDK fijado a una versión: el mismo resultado en cada despliegue.
RUN curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    | tar -xJ -C /opt \
    && git config --global --add safe.directory /opt/flutter
ENV PATH="/opt/flutter/bin:${PATH}"
RUN flutter config --no-analytics --enable-web \
    && flutter precache --web

WORKDIR /app
# Dependencias primero, para aprovechar la caché de capas.
COPY pubspec.yaml pubspec.lock* ./
RUN flutter pub get

COPY . .
# Si la variable llega vacía se usa el valor por defecto de arriba.
RUN URL="${API_URL:-https://cocoloco.sbs.mom}" \
    && echo "Compilando con API_URL=${URL}" \
    && flutter build web --release --no-wasm-dry-run \
       --dart-define=API_URL="${URL}"

# ---- Etapa 2: servir con nginx ----------------------------------------------
FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD wget -qO- http://127.0.0.1/healthz || exit 1
