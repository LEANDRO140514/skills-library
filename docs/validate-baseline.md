# SkillSpector — noise baseline (comunidad / producto)

**Fecha:** 2026-08-28 (scans corridos 2026-08-28 ~08:07 UTC)

**Pin:** SkillSpector v2.9.6 — `git+https://github.com/NVIDIA/SkillSpector.git@v2.9.6`
(mismo pin que el Skill Gate de CI; ver [README → Validate](../README.md#validate)).

**Modo:** `--no-llm` (análisis estático, `filtering_mode: heuristic`).

## Comando

El wrapper `scripts/scan-skills.sh` depende de `jq`, que no está en este entorno,
así que se corrió SkillSpector directamente (forma autorizada, equivalente al wrapper):

```bash
for s in add-emails add-mobile add-payments add-ui-kit supabase; do
  skillspector scan --no-llm --format json "backend/comunidad/$s" \
    > "reports/scan-backend-comunidad-$s.json"
done
```

Los JSON quedan en `reports/` (gitignored). No se suben JSON ni SARIF.

## Umbral vigente (sin cambios)

| Condición | verdict | banda |
|---|---|---|
| 0 critical, score 0–20 | `allow` | seguro |
| 0 critical, score 21–50 | `review` | precaución — necesita revisión Sentry + OK explícito o `scan_waiver` |
| ≥1 critical **o** score ≥ 51 | `deny` | no promover |

## Resultados

| skill | ruta | score | critical | verdict | top 3 rules | ¿FP? |
|---|---|---|---|---|---|---|
| add-emails | `backend/comunidad/add-emails` | 15 | 0 | `allow` (SkillSpector: SAFE) | PE3 ×1 (Credential Access — string `.env.local` en prosa) | Sí — el texto documenta dónde el usuario pega su API key de Resend; no hay código que lea credenciales. |
| add-mobile | `backend/comunidad/add-mobile` | 22 | 0 | `review` (SkillSpector: CAUTION) | RP1 ×3 (npx sin pin de versión), PE3 ×1 (string `.env.local`) | Sí — RP1 dispara sobre `npx web-push generate-vapid-keys` y sobre `allowed-tools: Bash(npx *)`; PE3 sobre prosa que lista las VAPID keys a configurar. |
| add-payments | `backend/comunidad/add-payments` | 0 | 0 | `allow` (SkillSpector: SAFE) | — (sin findings) | n/a — scan limpio. |
| add-ui-kit | `backend/comunidad/add-ui-kit` | 22 | 0 | `review` (SkillSpector: CAUTION) | RP1 ×8 (npx sin pin de versión), PE3 ×1 (string `.env.local`) | Sí — RP1 sobre `npx shadcn@latest add …` (comando de scaffolding idiomático) y sobre `Bash(npx *)`; PE3 sobre paso "agregar `NEXT_PUBLIC_HAS_AGENTATION=true` al `.env.local`". |
| supabase | `backend/comunidad/supabase` | 21 | 0 | `review` (SkillSpector: CAUTION) | PE3 ×5 (Credential Access — strings `.env` / "Access Token") | Sí — PE3 sobre un bloque `bash` que hace `grep '^SUPABASE_URL=' .env` para exportar env vars locales, y sobre una tabla que explica dónde encontrar el "Personal Access Token" en el dashboard. Patrón de documentación, no de robo. |

**Reglas observadas (2 IDs distintas en todo el set):**

- **PE3 — Privilege Escalation / Credential Access** (`HIGH`, conf 0.3–0.7): matchea las
  cadenas literales `.env`, `.env.local`, `Access Token` en texto de instrucciones. En estas
  5 skills siempre aparece en prosa que le dice al usuario dónde poner *sus propias* keys, no
  en código que lea archivos de credenciales.
- **RP1 — MCP Rug Pull** (`MEDIUM`, conf 0.7): comandos `npx` sin sufijo de versión
  (`npx web-push …`, `npx shadcn@latest …`) y la entrada `Bash(npx *)` del frontmatter
  `allowed-tools`. Es una observación de estilo razonable (pinear versiones), no un indicador
  de compromiso; el riesgo real depende del registry upstream, no de la skill.

Ninguna skill tiene componentes ejecutables (`has_executable_scripts: false` en las 5);
todo el score proviene de matching de texto sobre `SKILL.md` (+ `references/` en add-ui-kit
y supabase).

## Qué implica para Jewel

Las 5 skills salen de `C:\dev\jewel-ghl` y son representativas de cómo se escribe una skill
de producto de Jewel: instrucciones en español que mencionan archivos `.env`, pegan API keys
de ejemplo y usan comandos de scaffolding (`npx`, `npm`). El baseline dice que el **piso de
ruido** para una skill de Jewel legítima y bien escrita es **~15–22, no 0**, y que caer en la
banda `review` (21–50) por PE3/RP1 es el resultado *esperado*, no una señal de riesgo. El
único scan que dio 0 (`add-payments`) es el que casualmente no nombra `.env` ni `npx` en el
texto.

Esto **no justifica bajar el umbral**. La línea de `deny` (score ≥ 51 o cualquier CRITICAL)
se queda igual: es la que separa "documenta un patrón" de "ejecuta un patrón", y las 5 skills
están cómodamente por debajo (máx. 22, cero CRITICAL). Cuando una skill de Jewel caiga en
21–50, se despeja por el camino ya definido en el README — revisión Sentry + OK explícito, o
un `scan_waiver` que nombre PE3/RP1 como FP confirmado, o una exclusión de scope acotada en
`skill-gate.yml` — nunca con una reducción global del threshold. El valor de este documento es
servir de referencia: si una skill futura de Jewel puntúa bastante por encima de ~22, mete una
regla nueva (distinta de PE3/RP1), o marca `has_executable_scripts: true`, ahí sí hay que
mirar en serio.
