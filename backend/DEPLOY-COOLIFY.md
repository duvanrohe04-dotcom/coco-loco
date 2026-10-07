# Desplegar el backend en Coolify

Coolify construye el `Dockerfile` de esta carpeta directamente desde tu repositorio de GitHub.
La base de datos es un archivo SQLite, así que **necesita un volumen persistente** y **una sola
instancia** (no actives réplicas).

## 1. Subir el proyecto a GitHub

Crea un repositorio vacío en GitHub (sin README) y, desde la carpeta del proyecto:

```bash
git remote add origin https://github.com/TU_USUARIO/coco-loco.git
git push -u origin main --tags
```

## 2. Crear el servicio en Coolify

1. **Projects → tu proyecto → + New → Application**.
2. Origen: **Public Repository** (o *Private Repository with GitHub App* si es privado) y pega la URL.
3. Rama `main`. **Build Pack: `Dockerfile`**.
4. **Base Directory: `/backend`** (el Dockerfile y el código están ahí).
5. **Ports Exposes: `8787`**.
6. **Domains**: el dominio que quieras, con `https://` (por ejemplo `https://api.cocoloco.tudominio.com`).
   Coolify pide el certificado Let's Encrypt solo; el DNS del dominio debe apuntar a tu servidor.

## 3. Variables de entorno

| Variable      | Valor | Por qué                                                         |
|---------------|-------|-----------------------------------------------------------------|
| `TRUST_PROXY` | `1`   | Detrás de Traefik, para limitar intentos por IP real del cliente |

`PORT` y `DATA_DIR` ya vienen en el Dockerfile (`8787` y `/data`).

## 4. Volumen persistente (imprescindible)

**Persistent Storage → + Add → Volume Mount**:

- **Name**: `cocoloco-data`
- **Destination Path**: `/data`

Sin esto, cada despliegue borraría todas las cuentas y el progreso.

## 5. Health check

**Health Checks** → activa, método `GET`, ruta `/health`, puerto `8787`.
(El Dockerfile ya trae su propio `HEALTHCHECK`.)

## 6. Desplegar y comprobar

Pulsa **Deploy**. Cuando termine:

```bash
curl https://TU_DOMINIO/health          # → {"ok":true}
```

## 7. Despliegue automático (opcional)

En la aplicación de Coolify, **Webhooks → Manual Git Webhooks → GitHub**: copia la URL y el
secreto, y en GitHub **Settings → Webhooks → Add webhook** (tipo `application/json`, evento *push*).
Cada `git push` a `main` redespliega el backend.

## 8. Copias de seguridad

Coolify respalda sus bases de datos gestionadas, **no** un archivo SQLite dentro de un volumen.
Este proyecto trae un script de copia consistente:

**Scheduled Tasks → + Add**

- **Command**: `node src/backup.js`
- **Frequency**: `0 3 * * *` (cada día a las 3:00)
- **Container**: el de la aplicación

Guarda las copias en `/data/backups/` (dentro del mismo volumen) y conserva las últimas 7.
Para estar a salvo de un fallo del servidor, copia esa carpeta fuera de vez en cuando
(Coolify → **Terminal**, o `docker cp`).

## 9. Conectar la app Android

Con la URL ya funcionando, en GitHub: **Settings → Secrets and variables → Actions → Variables**
→ crea `API_URL` = `https://TU_DOMINIO` (sin `/` final). Las APK de los próximos Releases
saldrán ya conectadas a tu servidor.

## Problemas típicos

- **502 / Bad Gateway**: revisa que *Ports Exposes* sea `8787` y que el dominio use el puerto interno correcto.
- **Pierdo los datos al redesplegar**: falta el volumen en `/data` (paso 4).
- **`SQLITE_CANTOPEN` al arrancar**: el volumen no es escribible; el Dockerfile ya corrige permisos al
  iniciar, comprueba que el *Destination Path* sea exactamente `/data`.
- **Muchos "Demasiados intentos"**: falta `TRUST_PROXY=1` y todos los usuarios comparten la IP del proxy.
