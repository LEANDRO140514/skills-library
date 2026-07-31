# KB_07 - CONFIGURACION Y USO DEL SKILL

## Como activar

El skill se activa cuando el usuario menciona:
- "Quiero hacer un carrusel de Instagram"
- "Post de Instagram en formato carrusel"
- "Slides para IG" / "contenido para Instagram"
- "Carrusel Studio" directamente

Para forzar: "Usa el skill carrusel-studio para hacerme un carrusel sobre [tema]"

## Atajos

@reusar [sistema] - salta Fases 1-3
@brief - procesa Fase 4
@bigidea A/B/C - elige Big Idea
@estructura - genera estructura
@copy - genera copy completo
@build - HTML + render PNGs
@caption A/B/C - usa template
@express - modo rapido 30-40 min
@iteracion X - cambios sobre lo entregado
@principiante - explica todo despacito
@tecnico - detalle avanzado
@mockup - muestra preview visual

## Troubleshooting

Claude usa fuentes fuera de los 8 kits -> "Usa SOLO los 8 kits del skill KB_02"
Caption usa palabras prohibidas -> "Valida contra MI lista negra de Fase 3"
Impone tono que no es de la marca -> Especificar regionalismo en Fase 3
HTML < 100KB -> No embebio fuentes, verificar fonts_embedded.css
Tipografias en fallback en PNGs -> Agregar document.fonts.ready y timeout 3000ms
Kit no encaja -> Volver a Fase 1, especificar mas adjetivos
