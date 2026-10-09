# Despliegue en Coolify

Son dos aplicaciones del mismo repositorio: el **backend** (la API, ya desplegada en
`cocoloco.sbs.mom`) y la **web del juego** (para abrirlo desde el navegador, también en iPhone).

## 1. Backend

Ya está desplegado. Guía completa en [`backend/DEPLOY-COOLIFY.md`](backend/DEPLOY-COOLIFY.md)
(Base Directory `/backend`, volumen `/data`, variable `TRUST_PROXY=1`).

## 2. Web del juego (nueva)

Es **otra aplicación de Coolify** (no va dentro del backend). Así cada una tiene su propio dominio.

**La web la compila GitHub, no tu servidor.** Compilar Flutter exige bastante memoria y en servidores
pequeños el build se corta sin mensaje de error (código 255 justo en "Compiling lib/main.dart for the
Web…"). Por eso el workflow `.github/workflows/web.yml` compila la web en cada cambio de `lib/` o
`web/` y publica el resultado en la rama **`web-dist`**; Coolify solo sirve esos archivos con nginx.

### Pasos

1. Sube los cambios a `main` y espera a que el workflow **Web (build para Coolify)** termine (pestaña
   *Actions*, ~3 min). Eso crea la rama `web-dist`.
2. Coolify → *New Resource* → mismo repositorio (`coco-loco`), **rama `web-dist`** (no `main`).
3. **Build Pack**: `Dockerfile`.
4. **Base Directory**: `/` · **Dockerfile Location**: `/Dockerfile`.
5. **Ports Exposes**: `80`.
6. **Domains**: el que tengas apuntando a tu servidor (por ejemplo `https://juego.sbs.mom`; el DNS
   debe apuntar a la IP del servidor, igual que hiciste con `cocoloco.sbs.mom`).
7. Despliega. No hace falta ninguna variable de entorno en Coolify.

La URL del backend se incrusta al compilar en GitHub: por defecto `https://cocoloco.sbs.mom`; para
cambiarla crea la variable **`API_URL`** en *GitHub → Settings → Secrets and variables → Actions →
Variables* y vuelve a lanzar el workflow (*Actions → Web → Run workflow*).

### Despliegue automático (para que nadie se quede con una versión vieja)

Sin esto hay que pulsar *Redeploy* a mano después de cada cambio, y mientras no se haga el servidor
sigue sirviendo la versión anterior. Con dos secretos, el workflow le pide a Coolify que se redespliegue
solo cuando termina de compilar:

1. Coolify → **Keys & Tokens → API tokens** → crea un token con permiso de *deploy* y cópialo.
2. En la app de la web (rama `web-dist`) → **Webhooks** → copia la **Deploy Webhook** (algo como
   `http://TU_SERVIDOR:8000/api/v1/deploy?uuid=...&force=false`).
3. GitHub → repositorio → *Settings → Secrets and variables → Actions → Secrets*:
   - `COOLIFY_DEPLOY_URL` = la URL del paso 2
   - `COOLIFY_TOKEN` = el token del paso 1

A partir de ahí: **haces push a `main` y listo** (compila, publica en `web-dist` y Coolify despliega).
Si los secretos no existen, el workflow termina con un aviso amarillo y debes pulsar *Redeploy* a mano.

### Cómo evita las versiones antiguas en los dispositivos

Varias capas, para que no dependa de que el usuario haga nada:

1. **Sin service worker.** La web ya no instala ninguno (`web/flutter_bootstrap.js`), así que el navegador
   no puede guardar una copia vieja del juego.
2. **Limpiador para dispositivos viejos.** `flutter_service_worker.js` se publica como un "limpiador"
   (`deploy/web/cleanup_service_worker.js`): los dispositivos que ya tenían el service worker viejo lo
   descargan, borran su caché, se desinstalan y recargan.
3. **Guardián de versión** (`web/index.html`). Al abrir, compara `version.json` (siempre sin caché, con
   un número distinto en cada compilación) con la versión que el navegador vio por última vez; si cambió,
   limpia service workers y cachés y recarga una vez. Perfiles y progreso no se tocan.
4. **nginx** (`nginx.conf`): `index.html`, `version.json` y los `.js` nunca se sirven de caché sin
   preguntar al servidor si cambiaron; solo fuentes e imágenes se guardan una semana.
5. **`/reset.html`**: página de rescate. Si alguien aún ve el juego antiguo, abrir
   `https://TU_DOMINIO/reset.html` borra todo lo guardado y lo lleva al juego nuevo.

> Alternativa si tu servidor tiene memoria de sobra (≥ 4 GB libres): el `Dockerfile` de la raíz
> compila Flutter dentro de Docker (Base Directory `/`, rama `main`, variable de build `API_URL`).

### Comprobar

- `https://TU_DOMINIO/healthz` → `ok`
- `https://TU_DOMINIO/` → el juego (login)

### Instalarlo como app en el iPhone (sin App Store)

1. Abrir el enlace en **Safari**.
2. Botón **Compartir** → **Añadir a pantalla de inicio**.
3. Queda como una app, con el ícono de Mochi y a pantalla completa.

En Android, Chrome ofrece lo mismo: menú ⋮ → **Instalar app**.

## 3. APK de Android

Se publica como Release de GitHub (ver `README.md`). La app Android y la web comparten el mismo
backend y las mismas cuentas.

## Notas

- La web guarda los perfiles locales en el navegador de cada dispositivo. Las cuentas en línea viajan
  con el usuario entre la web y la APK.
- El backend permite llamadas desde cualquier origen (CORS abierto): la autenticación va por token en
  una cabecera, no por cookies.
