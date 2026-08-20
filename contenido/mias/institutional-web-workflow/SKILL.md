---
name: institutional-web-workflow
description: Flujo de trabajo para editar contenido, auditar y optimizar SEO/GEO de sitios web institucionales de marca (Vite/HTML estatico, sin backend). Usar cuando piden ajustes de copy sobre el sitio, una auditoria priorizada de que le falta a una pagina institucional, o visibilidad en buscadores tradicionales y motores de IA (schema.org, robots.txt, sitemap.xml, llms.txt).
---

# INSTITUTIONAL WEB WORKFLOW

Flujo de trabajo para mantener y mejorar sitios web institucionales de marca (sitios estáticos, sin backend, tipo Vite/HTML/CSS/JS vanilla) a lo largo de sesiones: ediciones de contenido, auditorías priorizadas, y optimización para buscadores tradicionales y motores de IA (GEO).

## Identidad

- Contexto: sitios institucionales de marca (landing única o pocas secciones), sin backend, deploy estático.
- Idioma: español, tono directo y técnico. Copy de marca puede estar en otro idioma — respetarlo, no traducirlo por iniciativa propia.
- Postura: implementar capacidades directamente con datos reales del proyecto. No instalar frameworks o agentes de terceros no verificados cuando la misma capacidad se logra directo.

## Reglas inquebrantables

1. **La fuente de verdad del render manda.** Antes de editar copy, verificar si el HTML está hardcodeado o si se genera desde un archivo de datos (ej. `site-content.js`). Si hay duplicación (HTML estático + data file no conectado al render), editar ambos y decirlo explícitamente — nunca asumir que el data file es lo que realmente se muestra.

2. **Ambigüedad que cambia el alcance se pregunta, no se adivina.** Si una instrucción admite dos lecturas que implican trabajo distinto (ej. una medida en px podría ser referencia de un asset o un requisito de layout), usar una pregunta estructurada con opciones concretas antes de tocar CSS/layout.

3. **Nunca reportar "listo" sin observar el resultado renderizado.** Después de cualquier cambio visible, usar el preview/dev server: navegar, leer el texto/DOM renderizado, revisar consola y network. Si el panel del navegador no está visible y no se puede verificar visualmente, decirlo explícitamente en vez de asumir que funcionó.

4. **Auditorías se fundamentan en el código real, no en checklists genéricos.** Cada hallazgo cita la línea/selector exacto del estado actual del repo. Cuando piden "un documento para revisar con calma", se entrega como documento con severidad (Crítico/Alto/Medio/Menor: evidencia → por qué importa → recomendación) y una hoja de ruta por fases al final — no como texto suelto de chat.

5. **GEO/SEO se implementa directo, no instalando frameworks de terceros sin verificar.** Antes de instalar un repo externo (pip install, npx desde GitHub de un autor no verificado), evaluar si la misma capacidad se puede producir directamente con las herramientas ya disponibles. Si de todos modos se instala, dejar explícito qué datos del proyecto se comparten con ese tercero, el costo/riesgo, y pedir confirmación explícita antes de ejecutar código ajeno.

6. **Nunca fabricar datos estructurados.** JSON-LD, fechas de eventos, ubicaciones o URLs de redes sociales solo se publican si existen ya en el proyecto (data files, footer, código existente). Si falta el dato (ej. fecha/sede de un evento), se deja pendiente explícitamente y se pide al usuario — no se inventa para "completar" el schema.

7. **Repos con su propio proceso de gobierno se respetan.** Si el repo destino documenta un flujo de promoción propio (branch aislado → validación → aprobación explícita → main), seguirlo. Push directo a `main` solo cuando el dueño del repo lo autoriza explícitamente en la conversación.

## Checklist GEO/SEO base (sitios institucionales estáticos)

Ver `references/geo-seo-baseline.md` para el detalle completo. Resumen:

- `<link rel="canonical">` con la URL real de producción.
- JSON-LD `Organization` (o subtipo específico, ej. `SportsOrganization`) con solo datos verificados del proyecto — sin `sameAs`/fechas inventadas.
- `robots.txt` + `sitemap.xml` en `public/` (o equivalente del framework) apuntando al dominio real.
- `llms.txt` en la raíz del sitio — resumen del negocio en Markdown plano, pensado para motores de respuesta de IA (GEO), no solo crawlers clásicos.
- `og:image` / `twitter:image` en raster real (PNG/JPG), nunca SVG — verificar las dimensiones reales del archivo antes de declarar `og:image:width`/`height`.

## Cierre de cada tarea

Terminar cada entrega indicando: qué se verificó (no solo qué se escribió), qué quedó pendiente de confirmar con el usuario (fechas, URLs, assets faltantes), y el siguiente paso concreto.
