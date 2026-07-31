---
name: video-pipeline
description: Pipeline de optimización y publicación de videos para web. Usa esta skill SIEMPRE que el usuario quiera optimizar, comprimir, convertir o publicar videos (MP4, MOV, WebM, MKV); preparar videos para heros, fondos animados o demos de una página web; generar versiones responsivas 1080p/720p, posters o thumbnails de video; quitar audio para autoplay silencioso; subir videos a un CDN o storage (Cloudflare R2, S3, Supabase, Vercel Blob); o generar catálogos VIDEO_URLS.ts / INDEX_PROD.json para React, Next.js o Vite. Aplica aunque solo diga "prepara estos videos para mi web" o entregue un ZIP/carpeta de videos.
---

# Video Pipeline

Convierte videos crudos en assets web listos: MP4 (H.264 + faststart) y WebM
por resolución, poster WebP, sin audio en fondos, publicados y catalogados.
Hermana de image-pipeline: mismos proveedores, misma filosofía, mismo bucket
posible (prefijos `images/` y `videos/`).

Modos: **optimize** (local, `url: null`) y **optimize-and-publish** (sube,
obtiene y valida cada URL; no está terminado hasta que TODAS validen).

Requiere ffmpeg/ffprobe (ya presentes en este entorno; en máquinas locales:
`winget install ffmpeg` o `apt install ffmpeg`).

## Flujo

1. **Recibir**: carpetas, archivos o ZIPs (uploads en /mnt/user-data/uploads).
2. **Inspeccionar**: `python scripts/inspect_videos.py <rutas> --out pipeline-work`
   → códec, dimensiones, duración, fps, audio, duplicados. Resume al usuario.
3. **Nombrar y clasificar (trabajo tuyo)**: revisa cada video (extrae un frame
   con ffmpeg si necesitas verlo: `ffmpeg -ss 2 -i video.mp4 -frames:v 1 f.png`
   y míralo con view). Escribe `pipeline-work/names.json` con name, category,
   role (`hero`/`background`/`demo`) y title. Formato: references/manifests.md.
   Regla clave: role `background` = sin audio (autoplay); pregunta al usuario
   si hay duda sobre conservar audio en heros/demos.
4. **Configurar**: `pipeline-work/pipeline.config.json` si el usuario pide
   algo distinto de los defaults (1080p+720p, MP4+WebM, poster al 10%).
5. **Procesar**: `python scripts/process_videos.py --work pipeline-work`.
   Avisa al usuario que la codificación de video tarda (VP9 especialmente);
   para lotes grandes o videos largos, considera ejecutar formato por formato.
   Nunca amplía resolución. Genera reporte de ahorro.
6. **Publicar** (solo optimize-and-publish): igual que image-pipeline —
   references/providers.md, variables de entorno, storage general
   `{base_prefix}/{categoria}/`. `python scripts/publish_assets.py --work
   pipeline-work`. Sin credenciales => not-published con url null, jamás
   inventes URLs.
7. **Validar**: `python scripts/validate_urls.py --work pipeline-work`
   (HTTP 200 + content-type video/* o image/* para posters). Falla => 
   diagnostica, corrige, re-valida.
8. **Manifiestos**: `python scripts/build_manifests.py --work pipeline-work`
   → INDEX_PROD.json, VIDEO_URLS.{json,ts,js}, urls.txt.
9. **Entregar**: copia a /mnt/user-data/outputs (dist como ZIP si pesa),
   present_files, resumen con ahorro y estado de URLs. Incluye el snippet
   `<video>` de ejemplo (está en el header del VIDEO_URLS.ts).

## Criterios de terminado

optimize: dist/ + manifiestos con url null + reporte. optimize-and-publish:
todo lo anterior + cada archivo (incluidos posters) con URL real validada.
URLs faltantes o inválidas = incompleto; dilo explícitamente.

## Advertencias específicas de video

- Peso: los WebM VP9 tardan en codificar; los MP4 salen rápido. Si el
  usuario tiene prisa, ofrece MP4-only primero (`"formats": ["mp4"]`).
- Videos verticales (móvil): la rotación en metadata ya se detecta en la
  inspección; las alturas se aplican sobre la orientación real.
- No procesar videos de más de ~5 minutos sin confirmar con el usuario:
  probablemente busca streaming (HLS), que está fuera del alcance de esta
  skill orientada a web assets.

## Referencias

- references/providers.md — proveedores y variables de entorno (compartido
  con image-pipeline).
- references/manifests.md — names.json, config y catálogos.
