# Coco Loco

Juego de atrapar cocos hecho con Flutter (Android y web) + backend Node.js para cuentas, progreso
en la nube y ranking.

```
lib/        App Flutter          backend/   API (ver backend/README.md)
android/    Proyecto Android     dist/      APKs listas para instalar
```

## Cómo se juega

Vista pseudo-3D: los objetos vienen desde el horizonte hacia ti y tú te mueves de lado a lado
(arrastrando el dedo, o con las flechas / A y D del teclado). **Atrapa los cocos, esquiva lo malo.**

| Objeto | Qué hace |
|---|---|
| 🥥 Coco | +1 punto. Si pasa de largo pierdes una vida |
| 🥥 Coco dorado | +3 puntos |
| 🪨 Roca | Quita una vida (esquívala) |
| 💣 Bomba | Quita una vida y te **aturde** un momento |
| ❤️ Corazón | +1 vida (hasta 2 de más) |
| 🛡️ Escudo | Bloquea el siguiente golpe |
| 🧲 Imán | 7 s: los cocos vienen hacia ti |
| ⏳ Reloj | 5 s de cámara lenta |
| ✖️2 Moneda | 8 s de puntos dobles |

- **Rachas:** cada 5 cocos seguidos sin fallar dan un punto extra.
- **Oleadas:** cocos sueltos, filas de tres (se atrapan de golpe), zigzags y **paredes de rocas con un hueco**.
- **20 niveles** en 7 escenarios (amanecer, playa, atardecer, tormenta, noche, volcán y aurora). Cada mecánica
  nueva se presenta con un consejo. En los niveles **5, 10, 15 y 20** hay un **jefe** cuya vida baja al atrapar cocos.
- **Estrellas:** 3 si no pierdes vidas, 2 si pierdes una, 1 en otro caso.
- El generador de oleadas es **justo**: nunca pone dos premios seguidos imposibles de alcanzar (hay una prueba
  automática que lo comprueba) y las distancias de los patrones se miden en píxeles, igual en móvil que en PC.

## Sonido

Todo el audio (efectos y música tropical de fondo) **se genera por código** (`lib/core/synth.dart`), así que
no hay archivos de audio ni derechos de autor de por medio. Suena al atrapar cocos, con los poderes, los golpes,
las bombas, las rachas, la cuenta atrás y al ganar o perder. El altavoz del menú (o el interruptor de la pausa) lo
silencia y la preferencia se guarda. La música se pausa con el juego, se hace lenta con la cámara lenta y se detiene
si sales de la app. Para escuchar todos los sonidos en el PC: `OUT_DIR=sonidos flutter test tool/export_sounds.dart`.

## Dos modos de juego

- **Sin servidor** (por defecto): perfiles locales en el dispositivo, sin contraseña.
- **Con servidor**: si compilas con `--dart-define=API_URL=...` aparecen las cuentas en línea
  (usuario + contraseña), el progreso se sincroniza y se activa el ranking.

## Generar la APK de Android

```bash
# Prueba (sin backend)
flutter build apk --release --target-platform android-arm,android-arm64

# Con backend desplegado (la URL debe ser https://)
flutter build apk --release --split-per-abi --dart-define=API_URL=https://tu-api.onrender.com
```

Salen en `build/app/outputs/flutter-apk/`. Para casi todos los móviles actuales sirve
`app-arm64-v8a-release.apk` (~17 MB). Para instalarla: copia el archivo al teléfono y ábrelo
(hay que permitir "instalar apps de origen desconocido").

Para Google Play se sube un App Bundle: `flutter build appbundle --release --dart-define=API_URL=...`

### Firma (importante)

`android/upload-keystore.jks` y `android/key.properties` se generaron para firmar la app.
**Guarda una copia segura de ambos archivos y de la contraseña**: sin ellos no podrás publicar
actualizaciones de la misma app. Están en `.gitignore`; nunca los subas a un repositorio.

Antes de publicar en Play Store cambia, si quieres, el identificador `com.cocoloco.game`
(en `android/app/build.gradle.kts` y la carpeta de `MainActivity.kt`): después de publicar no se puede cambiar.

### Si Gradle falla con `PKIX path building failed`

Tu antivirus (p. ej. Avast) inspecciona HTTPS con su propio certificado y Java no confía en él.
Crea una copia del almacén de Java que lo incluya y úsala en esa terminal:

```powershell
$jdk = "<ruta a tu JDK>"
Copy-Item "$jdk\lib\security\cacerts" "$env:TEMP\cacerts-av"
& "$jdk\bin\keytool.exe" -importcert -noprompt -alias antivirus -file "<ruta al .pem de tu antivirus>" -keystore "$env:TEMP\cacerts-av" -storepass changeit
$env:JAVA_TOOL_OPTIONS = "-Djavax.net.ssl.trustStore=$env:TEMP\cacerts-av -Djavax.net.ssl.trustStorePassword=changeit"
flutter build apk --release
```

(La alternativa es desactivar la inspección HTTPS del antivirus.)

## Publicar la APK como GitHub Release (link para compartir)

Al subir una etiqueta `v*`, GitHub Actions compila la APK firmada y la adjunta a un Release
público. El enlace de descarga es permanente (`https://github.com/TU_USUARIO/coco-loco/releases/latest`).

**Configuración, una sola vez** (GitHub → repositorio → *Settings → Secrets and variables → Actions*):

| Tipo       | Nombre              | Valor                                                                 |
|------------|---------------------|-----------------------------------------------------------------------|
| Secret     | `KEYSTORE_BASE64`   | La clave en base64 (comando abajo)                                    |
| Secret     | `KEYSTORE_PASSWORD` | La contraseña de `android/key.properties` (`storePassword`)           |
| Variable   | `API_URL`           | `https://tu-api...` (si no hay backend, déjala vacía)                 |

```powershell
# Copia la clave al portapapeles en base64 (luego pégala en el secreto KEYSTORE_BASE64)
[Convert]::ToBase64String([IO.File]::ReadAllBytes("android\upload-keystore.jks")) | Set-Clipboard
```

**Cada versión nueva:**

```bash
# 1. Sube el número en pubspec.yaml si quieres (el workflow ya usa la etiqueta como versión)
git tag v1.0.1
git push origin v1.0.1
```

En unos 10 minutos aparece en *Releases* con `coco-loco-1.0.1-arm64.apk` (casi todos los móviles)
y `coco-loco-1.0.1-armv7.apk` (móviles antiguos). Ese es el link que compartes.

> El repositorio puede ser público o privado; si es privado, solo quien tenga acceso podrá descargar el Release.
> Para compartir con cualquiera, el repositorio (o un repo aparte solo para releases) debe ser público.

## Web

```bash
flutter build web --release --dart-define=API_URL=https://tu-api.onrender.com
```

Sube `build/web` a cualquier hosting estático. El backend ya permite CORS.

## Pruebas

```bash
flutter analyze && flutter test      # app
cd backend && npm test               # API
```
