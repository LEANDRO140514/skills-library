# Proveedores de storage

El pipeline usa **storage general, no por proyecto**: un solo bucket/store con
rutas `{base_prefix}/{categoria}/{archivo}` (por defecto `images/...`). Así las
URLs son estables y reutilizables entre proyectos.

Configura el proveedor en `pipeline.config.json` (`"provider"`) y las
credenciales como variables de entorno. Si el usuario pega credenciales en el
chat, expórtalas en la misma sesión de bash antes de ejecutar
`publish_assets.py`; no las guardes en archivos.

## s3 (Amazon S3, Cloudflare R2, InsForge, MinIO, Supabase S3, etc.)

El modo más universal. Requiere boto3:
`pip install boto3 --break-system-packages`

| Variable | Descripción |
|---|---|
| `S3_BUCKET` | Nombre del bucket |
| `S3_ACCESS_KEY_ID` | Access key |
| `S3_SECRET_ACCESS_KEY` | Secret key |
| `S3_PUBLIC_BASE_URL` | Base pública de las URLs finales (sin `/` final) |
| `S3_ENDPOINT` | Opcional. Obligatorio para R2/InsForge/MinIO/Supabase |
| `S3_REGION` | Opcional (`auto` por defecto) |

Ejemplos de `S3_PUBLIC_BASE_URL`:
- Amazon S3: `https://mi-bucket.s3.us-east-1.amazonaws.com`
- Cloudflare R2 con dominio propio: `https://cdn.midominio.com`
- R2 dev: `https://pub-xxxx.r2.dev`

Ejemplos de `S3_ENDPOINT`:
- R2: `https://<account_id>.r2.cloudflarestorage.com`
- Supabase: `https://<proyecto>.supabase.co/storage/v1/s3`
- InsForge: consultar el dashboard del proyecto (expone endpoint S3-compatible;
  si solo hay API REST, revisar su documentación actual antes de improvisar).

El bucket debe permitir lectura pública (o estar detrás de un CDN público);
de lo contrario la validación de URLs fallará.

## supabase (REST nativo, sin boto3)

| Variable | Descripción |
|---|---|
| `SUPABASE_URL` | `https://<proyecto>.supabase.co` |
| `SUPABASE_SERVICE_KEY` | Service role key (no la anon key) |
| `SUPABASE_BUCKET` | Bucket, debe ser **público** |

URL resultante: `{SUPABASE_URL}/storage/v1/object/public/{bucket}/{key}`.

## vercel-blob

| Variable | Descripción |
|---|---|
| `BLOB_READ_WRITE_TOKEN` | Token read-write del store |

La URL final la devuelve la API de Vercel (dominio
`*.public.blob.vercel-storage.com`).

## Otro proveedor compatible

Cualquier storage con API S3-compatible funciona con el modo `s3`. Para uno
totalmente distinto, busca su documentación actual, explica al usuario qué
credenciales necesitas y adapta la subida con `requests`, pero mantén el
contrato: mismas claves de storage, actualizar `url` en `processed.json` y
pasar por `validate_urls.py`.

## Sin proveedor o sin credenciales

`publish_assets.py` lo detecta solo: completa el procesamiento local, deja
`url: null`, marca `status: not-published` e imprime exactamente qué variables
faltan. Nunca inventes URLs ni placeholders con pinta de URL real.
