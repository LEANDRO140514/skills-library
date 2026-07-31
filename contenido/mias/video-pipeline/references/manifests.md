# Formatos de archivos del pipeline de video

## names.json (lo escribe Claude tras revisar los videos)

```json
{
  "/ruta/VID_1234.mp4": {
    "name": "hero-producto-principal",
    "category": "hero",
    "role": "background",
    "title": "Demo del producto en el hero principal",
    "keep_audio": false
  }
}
```

- `name`: semántico, minúsculas con guiones. Nunca genérico.
- `category`: subcarpeta en dist/ y storage (`hero`, `demos`, `fondos`, ...).
- `role`: `hero` | `background` | `demo`. background elimina audio por
  defecto (autoplay silencioso); `keep_audio: true` lo conserva.
- `title`: descripción para accesibilidad/metadata.

## pipeline.config.json

```json
{
  "mode": "optimize-and-publish",
  "heights": [1080, 720],
  "formats": ["mp4", "webm"],
  "crf_h264": 23,
  "crf_vp9": 33,
  "poster": true,
  "poster_second": null,
  "max_fps": 30,
  "base_prefix": "videos",
  "provider": "s3"
}
```

Todos opcionales. `poster_second: null` = frame al 10% de la duración.
`heights` nunca amplía: solo genera alturas <= a la original.

## VIDEO_URLS.ts — uso en el frontend

```tsx
import { VIDEOS } from "./VIDEO_URLS";

<video poster={VIDEOS.heroProducto.poster} autoPlay muted loop playsInline>
  <source src={VIDEOS.heroProducto.webm} type="video/webm" />
  <source src={VIDEOS.heroProducto.mp4} type="video/mp4" />
</video>
```

`sources` trae todas las resoluciones (`h1080`, `h720`) por formato para
media queries o selección adaptativa manual.

## Estados (`status`)

`processed` → `published` → `validation-failed` si una URL no valida.
Sin credenciales: `not-published` con `url: null` (jamás se inventan URLs).
