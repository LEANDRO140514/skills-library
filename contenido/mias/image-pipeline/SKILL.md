---
name: image-pipeline
description: Pipeline completo de optimización y publicación de imágenes para proyectos web. Usa esta skill SIEMPRE que el usuario quiera optimizar, comprimir, convertir a WebP, renombrar, organizar o publicar imágenes o assets visuales; subir imágenes a un CDN o storage (Vercel Blob, Cloudflare R2, S3, Supabase, InsForge); generar tamaños responsivos o thumbnails; obtener URLs públicas de sus imágenes; o generar catálogos/manifiestos de imágenes (INDEX_PROD.json, IMAGE_URLS.ts) para React, Next.js, Vite o un CMS. Aplica aunque solo diga "prepara estas imágenes para mi web", "sube estos assets" o entregue un ZIP/carpeta de imágenes.
---

# Image Pipeline

Convierte una carpeta, archivos sueltos o un ZIP de imágenes en un set
optimizado, bien nombrado, publicado en storage y catalogado en manifiestos
listos para código.

Dos modos:
- **optimize**: solo procesamiento local. Los manifiestos llevan `url: null`.
- **optimize-and-publish**: además sube al proveedor configurado, obtiene y
  valida cada URL. **No está terminado hasta que TODAS las URLs existan y
  validen.**

Directorio de trabajo: crea `pipeline-work/` (o el nombre que prefiera el
usuario) y ejecuta todos los scripts con `--work` apuntando ahí. Los scripts
viven en `scripts/` dentro de esta skill; ejecútalos desde ese directorio o
con la ruta completa (importan `common.py` de su misma carpeta).

## Flujo

### 1. Recibir los archivos

Acepta carpetas, archivos individuales o ZIPs (los ZIP se extraen solos).
Los uploads del usuario están en `/mnt/user-data/uploads`. Si las imágenes
vienen de una URL, descárgalas primero con web_fetch o curl. Si vienen de
Google Drive u otra fuente conectada, tráelas con la herramienta correspondiente.

### 2. Inspeccionar

```bash
python scripts/inspect_assets.py <rutas...> --out pipeline-work
```

Genera `pipeline-work/inventory.json` con formato, dimensiones, orientación,
transparencia, peso, hash (duplicados exactos), si el nombre es genérico y una
clasificación heurística (`guessed_type`). Léelo y resume al usuario qué hay:
cuántos archivos, duplicados, nombres genéricos, errores.

### 3. Nombrar y clasificar (trabajo tuyo, no del script)

**Mira las imágenes** con la herramienta view (son archivos de imagen; abre al
menos las de nombre genérico y las de clasificación dudosa). Con lo que veas,
escribe `pipeline-work/names.json`: nombre semántico, categoría, tipo visual
(`photo` | `graphic` | `icon` | `vector`) y texto alternativo por archivo.
Formato exacto en `references/manifests.md`.

Reglas de nombres: minúsculas, guiones, sin espacios/acentos/caracteres
especiales, semánticos y descriptivos. Prohibidos `img-2345`, `final-final`,
`image1` y similares. Si un nombre original ya es bueno, consérvalo slugificado.
El alt describe el contenido real, en el idioma del proyecto del usuario.

Si son muchas imágenes (>20) o el contexto no basta para nombrarlas bien,
muestra al usuario tu propuesta de nombres/categorías antes de procesar.

### 4. Configurar

Escribe `pipeline-work/pipeline.config.json` según lo que pida el usuario
(modo, tamaños, calidad, proveedor). Defaults razonables si no pide nada:
widths `[1920, 1200, 800, 400]`, thumbnail 320, calidad 82, prefix `images`.
Campos en `references/manifests.md`.

### 5. Procesar

```bash
python scripts/process_images.py --work pipeline-work
```

Hace por ti: renombrado, fotos → WebP con pérdida, gráficos/logos → WebP
lossless conservando transparencia, SVG copiado tal cual, GIF animado → WebP
animado, tamaños responsivos **sin ampliar jamás**, thumbnails, organización
en `dist/<categoria>/`, y `reports/optimization-report.md`. Aborta si dos
assets colisionan en nombre final: corrige names.json y reintenta.

**Vectorización**: solo si el usuario la pide explícitamente y solo para
logos/íconos/gráficos planos aptos (pocos colores, bordes definidos). Usa
`pip install vtracer --break-system-packages` y revisa visualmente el SVG
resultante antes de incluirlo. Nunca vectorices fotografías.

### 6. Publicar (solo modo optimize-and-publish)

Lee `references/providers.md` para el proveedor elegido y sus variables de
entorno. El storage es **general, no por proyecto**: rutas
`{base_prefix}/{categoria}/{archivo}` en un único bucket reutilizable.

```bash
export S3_BUCKET=... S3_ACCESS_KEY_ID=...   # según proveedor
python scripts/publish_assets.py --work pipeline-work
```

Si no hay proveedor o faltan credenciales, el script marca todo
`not-published` con `url: null` e indica exactamente qué variables faltan.
Transmite eso al usuario tal cual, genera igualmente los manifiestos locales
y **nunca inventes URLs**.

### 7. Validar URLs

```bash
python scripts/validate_urls.py --work pipeline-work
```

Comprueba HTTP 200, content-type de imagen y accesibilidad de cada URL;
escribe `reports/publish-report.md`. Si algo falla (exit code 1), diagnostica
(¿bucket privado? ¿base URL mal? ¿propagación?), corrige, re-publica lo
fallido y re-valida. No declares el trabajo terminado con URLs inválidas.

### 8. Manifiestos

```bash
python scripts/build_manifests.py --work pipeline-work
```

Genera en `pipeline-work/manifests/`: `INDEX_PROD.json` (catálogo maestro),
`IMAGE_URLS.json`, `IMAGE_URLS.ts`, `IMAGE_URLS.js` y `urls.txt`. Esquemas en
`references/manifests.md`.

### 9. Entregar

Copia a `/mnt/user-data/outputs/` y presenta con present_files:
- la carpeta `dist/` (como ZIP si son muchos archivos:
  `cd pipeline-work && zip -r /mnt/user-data/outputs/imagenes-optimizadas.zip dist`);
- los 5 manifiestos;
- `optimization-report.md` y `publish-report.md`.

Cierra con un resumen corto: cuántos assets, ahorro de peso, proveedor y
estado de las URLs (o qué configuración falta para publicar).

## Criterios de terminado

- `optimize`: dist/ completo + manifiestos con `url: null` + reporte de
  optimización.
- `optimize-and-publish`: todo lo anterior **+ cada archivo subido, con URL
  real obtenida del proveedor y validada con HTTP 200 y content-type de
  imagen**. URLs faltantes o inválidas = trabajo incompleto; dilo
  explícitamente y ofrece el siguiente paso.

## Referencias

- `references/providers.md` — proveedores, variables de entorno, URLs públicas.
- `references/manifests.md` — esquemas de names.json, config y manifiestos.
