# Checklist GEO/SEO base — sitios institucionales estáticos

Aplicar sobre el `<head>` del HTML principal y la carpeta pública del sitio (ej. `public/` en Vite). Todos los valores deben salir del proyecto real (footer, data files, dominio de producción) — nunca inventar fechas, direcciones ni handles de redes.

## 1. `<head>`

- `<link rel="canonical" href="https://TU-DOMINIO/">`
- Meta description real (no genérica), acorde a la marca.
- Open Graph: `og:title`, `og:description`, `og:type`, `og:url`, `og:image` (raster real, no SVG), `og:image:width`, `og:image:height`, `og:image:alt`, `og:locale`.
- Twitter Card: `twitter:card` (`summary_large_image` si hay imagen decente), `twitter:title`, `twitter:description`, `twitter:image`.
- JSON-LD `<script type="application/ld+json">` con `@type` ajustado al rubro (`Organization`, `SportsOrganization`, `LocalBusiness`, etc.):
  - `name`, `alternateName`, `url`, `logo`, `description`, `slogan` si existe.
  - `address` con solo los campos que el proyecto ya declara (ej. ciudad/país si eso es lo único conocido — no inventar calle/CP).
  - `email` solo si ya está publicado en el sitio.
  - `sameAs`: solo URLs deterministas a partir de un handle ya conocido (ej. `instagram.com/<handle>`, `tiktok.com/@<handle>`). Si una red social no tiene handle/slug verificado (ej. solo el nombre del Facebook page), omitirla — no adivinar la URL.

## 2. `public/robots.txt`

```
User-agent: *
Allow: /

Sitemap: https://TU-DOMINIO/sitemap.xml
```

## 3. `public/sitemap.xml`

Para un sitio de una sola página, un `<url>` por página real (no por ancla `#section`):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://TU-DOMINIO/</loc>
    <lastmod>YYYY-MM-DD</lastmod>
    <changefreq>monthly</changefreq>
    <priority>1.0</priority>
  </url>
</urlset>
```

## 4. `public/llms.txt` (GEO — motores de respuesta de IA)

Convención `llms.txt`: título H1, un blockquote de resumen, y secciones en Markdown con links reales. Es el equivalente a un "elevator pitch" legible por máquina para que un motor de IA pueda citar la marca correctamente sin tener que renderizar JS.

```markdown
# Nombre de la marca

> Resumen de una línea: qué es, dónde opera, qué la distingue.

Párrafo corto con el modelo de negocio si es relevante (ej. propio vs. servicio a clientes).

## Sección temática 1
- [Producto/proyecto](https://url-real): descripción corta.

## Contacto
- Email: ...
- Redes: ... (solo las reales)
- Ubicación: ...
```

## 5. Verificación

- Levantar el dev server, navegar a `/robots.txt`, `/sitemap.xml`, `/llms.txt` y confirmar que sirven texto plano (no el HTML de la SPA).
- Parsear el JSON-LD en consola (`JSON.parse` sobre el `textContent` del script) para confirmar que no tiene errores de sintaxis.
- Revisar consola y logs del server por errores antes de reportar terminado.
