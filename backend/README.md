# Coco Loco â€“ Backend

API REST para cuentas, progreso en la nube y ranking. Node.js â‰¥ 22.13, **sin dependencias**
(usa `node:sqlite`, `crypto.scrypt` y `node:http`).

## Ejecutar en local

```bash
npm start          # http://localhost:8787
npm test           # 21 pruebas
```

Variables de entorno:

| Variable      | Por defecto | Para quÃ© sirve                                                        |
|---------------|-------------|-----------------------------------------------------------------------|
| `PORT`        | `8787`      | Puerto HTTP                                                           |
| `DATA_DIR`    | `./data`    | Carpeta del archivo SQLite (en producciÃ³n, un volumen persistente)    |
| `MAX_LEVEL`   | `20`        | Niveles vÃ¡lidos al guardar progreso                                   |
| `TRUST_PROXY` | _(vacÃ­o)_   | Pon `1` detrÃ¡s de un proxy/balanceador para limitar por IP real       |

## Endpoints

Las respuestas son JSON. Rutas con ðŸ”’ piden `Authorization: Bearer <token>`.

| MÃ©todo y ruta                | Cuerpo                                | Resultado                                  |
|------------------------------|---------------------------------------|--------------------------------------------|
| `GET /health`                |                                       | `{ok:true}`                                |
| `POST /api/register`         | `{username, password}`                | `201 {token, profile}`                     |
| `POST /api/login`            | `{username, password}`                | `{token, profile}`                         |
| `POST /api/logout` ðŸ”’        |                                       | cierra esa sesiÃ³n                          |
| `GET /api/me` ðŸ”’             |                                       | `profile`                                  |
| `PUT /api/me` ðŸ”’             | `{character}`                         | `profile` (`mochi`, `dino`, `robot`)       |
| `PUT /api/progress` ðŸ”’       | `{level, stars, streak}`              | `profile` (solo guarda mejoras)            |
| `POST /api/progress/merge` ðŸ”’| `{stars:{1:3}, streaks:{1:7}}`        | `profile` (fusiona el progreso local)      |
| `GET /api/leaderboard`       |                                       | `{players:[{username,character,stars,bestStreak}]}` (top 20) |
| `DELETE /api/me` ðŸ”’          |                                       | borra la cuenta y sus datos                |

`profile = {username, character, stars:{nivel:n}, streaks:{nivel:n}}`

Usuario: 3â€“16 caracteres `A-Za-z0-9_` (sin distinguir mayÃºsculas). ContraseÃ±a: 8â€“72 caracteres.

## Seguridad (quÃ© hace y quÃ© no)

- ContraseÃ±as con `scrypt` + sal propia; comparaciÃ³n en tiempo constante; el login tarda igual
  exista o no el usuario y devuelve el mismo mensaje.
- Tokens de sesiÃ³n aleatorios (256 bits); en la base solo se guarda su hash SHA-256. Caducan a los
  90 dÃ­as y se revocan con `/logout`.
- LÃ­mite de 15 intentos de login/registro por IP cada 10 minutos; cuerpo mÃ¡ximo de 10 KB.
- El progreso lo informa la app: **un jugador con malas intenciones podrÃ­a enviar estrellas falsas**.
  Sirve para un juego casual; un ranking competitivo necesitarÃ­a validar partidas en el servidor.
- Sirve **siempre detrÃ¡s de HTTPS** (las plataformas de abajo ya lo dan).
- No hay recuperaciÃ³n de contraseÃ±a (no se pide correo). Si se olvida, hay que crear otra cuenta.

## Desplegar

GuÃ­a paso a paso para **Coolify**: [DEPLOY-COOLIFY.md](DEPLOY-COOLIFY.md).
Copia de seguridad: `node src/backup.js` (ver esa guÃ­a).

Otras plataformas: necesitan **disco persistente** para el archivo SQLite (en `DATA_DIR`).
Con el `Dockerfile` incluido:

**Render** â€“ _New â†’ Web Service_ â†’ repositorio â†’ _Root directory_: `backend` â†’ _Runtime_: Docker â†’
aÃ±ade un _Disk_ montado en `/data` â†’ variables `TRUST_PROXY=1`. (Los discos requieren plan de pago.)

**Fly.io**
```bash
cd backend
fly launch --no-deploy          # elige regiÃ³n; acepta el Dockerfile
fly volumes create data --size 1
# en fly.toml: [mounts] source="data" destination="/data"  y  [env] TRUST_PROXY="1"
fly deploy
```

**Railway** â€“ servicio desde el repo (`backend`), _Volume_ en `/data`, variable `TRUST_PROXY=1`.

Para probar con Docker en tu equipo:
```bash
docker build -t coco-loco-api .
docker run -p 8787:8787 -v cocoloco-data:/data coco-loco-api
```

Cuando tengas la URL pÃºblica (por ejemplo `https://coco-loco-api.onrender.com`), compila la app con:
```bash
flutter build apk --release --dart-define=API_URL=https://coco-loco-api.onrender.com
```
