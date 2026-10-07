# Migraciones SQL

El esquema de la base de datos vive en estos archivos `.sql`. Al arrancar, el servidor aplica
en orden las migraciones que falten (y anota cada una en la tabla `schema_migrations`).

## Reglas

- Nombre: `NNN_descripcion.sql` (tres dígitos, p. ej. `002_add_avatar_color.sql`). Se aplican por orden alfabético.
- **Nunca edites una migración ya publicada**: crea una nueva. Cada migración se aplica una sola vez.
- Cada archivo se ejecuta dentro de una transacción: si algo falla, no queda a medias y el servidor no arranca.
- Mantén las migraciones compatibles con bases que ya tienen datos (por ejemplo, `ALTER TABLE ... ADD COLUMN ... DEFAULT ...`).

## Ejemplo

```sql
-- 002_user_country.sql
ALTER TABLE users ADD COLUMN country TEXT NOT NULL DEFAULT '';
```

## Comandos

```bash
npm run migrate        # aplica pendientes y muestra el estado
```
