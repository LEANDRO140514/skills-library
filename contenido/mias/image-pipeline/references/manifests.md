# Formatos de archivos del pipeline

## names.json (lo escribe Claude tras ver las imágenes)

Mapa de ruta original (la clave `path` de inventory.json) a metadatos:

```json
{
  "/ruta/original/IMG_2345.jpg": {
    "name": "equipo-oficina-merida",
    "category": "team",
    "type": "photo",
    "alt": "Equipo de la empresa reunido en la oficina de Mérida"
  },
  "/ruta/original/logo (1).png": {
    "name": "logo-acme-principal",
    "category": "brand",
    "type": "graphic",
    "alt": "Logotipo principal de Acme"
  }
}
```

- `name`: semántico y descriptivo, en minúsculas con guiones. Nunca genérico.
- `category`: agrupa por uso (`hero`, `brand`, `products`, `team`, `icons`,
  `backgrounds`, `gallery`, ...). Define la subcarpeta en dist/ y en storage.
- `type`: `photo` (WebP con pérdida), `graphic`/`icon` (WebP lossless,
  conserva transparencia), `vector` (SVG, se copia tal cual).
- `alt`: texto alternativo real y descriptivo, en el idioma del proyecto.

Los duplicados exactos no necesitan entrada (se omiten automáticamente).

## pipeline.config.json

```json
{
  "mode": "optimize-and-publish",
  "widths": [1920, 1200, 800, 400],
  "thumbnail_width": 320,
  "quality": 82,
  "max_width": 2560,
  "base_prefix": "images",
  "provider": "s3"
}
```

Todos los campos son opcionales (hay defaults). `provider`:
`s3` | `supabase` | `vercel-blob` | `null`.
`thumbnail_width: null` desactiva thumbnails.

## INDEX_PROD.json (catálogo maestro)

Por asset: id, name, category, type, alt, original_name, status, provider,
hash sha256, url principal, width/height, format, lista de `variants`
(width, height, format, bytes, path relativo, url) y `thumbnail`.
Cabecera con `generated_at`, provider, base_prefix, count, duplicates, errors.

## IMAGE_URLS.json / .ts / .js

Objeto plano con claves camelCase derivadas del nombre:

```json
{
  "equipoOficinaMerida": {
    "url": "https://cdn.../images/team/equipo-oficina-merida-w1920.webp",
    "alt": "Equipo de la empresa reunido en la oficina de Mérida",
    "width": 1920,
    "height": 1280,
    "sizes": {
      "w1920": "https://...-w1920.webp",
      "w1200": "https://...-w1200.webp",
      "w800": "https://...-w800.webp"
    },
    "thumb": "https://...-thumb.webp"
  }
}
```

El `.ts` exporta `IMAGES ... as const satisfies Record<string, ImageAsset>`
con la interfaz incluida; el `.js` exporta el mismo objeto. Assets no
publicados llevan `url: null` y `published: false`.

## urls.txt

Listado humano: `nombre  ->  URL` con variantes y thumb indentados.

## Estados posibles de un asset (`status`)

`processed` → `published` → (tras validar) se mantiene `published` o pasa a
`validation-failed`. Sin credenciales: `not-published`.
Fallo de subida: `publish-failed`.
