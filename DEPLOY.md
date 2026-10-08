# Despliegue en Coolify

Son dos aplicaciones del mismo repositorio: el **backend** (la API, ya desplegada en
`cocoloco.sbs.mom`) y la **web del juego** (para abrirlo desde el navegador, también en iPhone).

## 1. Backend

Ya está desplegado. Guía completa en [`backend/DEPLOY-COOLIFY.md`](backend/DEPLOY-COOLIFY.md)
(Base Directory `/backend`, volumen `/data`, variable `TRUST_PROXY=1`).

## 2. Web del juego (nueva)

Es **otra aplicación de Coolify** (no va dentro del backend). Así cada una tiene su propio dominio.

### Pasos

1. Coolify → *New Resource* → mismo repositorio (`coco-loco`), rama `main`.
2. **Build Pack**: `Dockerfile`.
3. **Base Directory**: `/` · **Dockerfile Location**: `/Dockerfile`.
4. **Ports Exposes**: `80`.
5. **Environment Variables**, marcada como *Build Variable*:

   | Variable | Valor |
   |---|---|
   | `API_URL` | `https://cocoloco.sbs.mom` (la URL pública del backend, sin `/` al final) |

6. **Domains**: el que tengas apuntando a tu servidor (por ejemplo `https://juego.sbs.mom`; el DNS
   debe apuntar a la IP del servidor, igual que hiciste con `cocoloco.sbs.mom`).
7. Despliega.

`API_URL` se incrusta al compilar: si cambias la URL del backend hay que volver a desplegar la web.
El primer build descarga el SDK de Flutter (~1,5 GB) y tarda varios minutos; los siguientes
reutilizan la caché de capas.

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
