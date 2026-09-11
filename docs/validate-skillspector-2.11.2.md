# Validate baseline — SkillSpector v2.11.2 (2026-09-11)

Baseline del Skill Gate para las 64 filas de `comunidad` que estaban sin `scan_verdict` y por lo
tanto resolvían como `blocked` en `find-skills`.

- **Herramienta:** SkillSpector v2.11.2, estático, `--no-llm` (`filtering_mode: heuristic`).
- **Fecha:** 2026-09-11. Un JSON por skill, 99 scans, `execution_successful: true` en todos.
- **Mapeo de score** (el mismo umbral que `scripts/scan-skills.sh` y el Skill Gate de CI):

| score | veredicto |
|---|---|
| 0-20 | `allow` |
| 21-50 | `review` + `scan_waiver` |
| ≥51 | análisis caso por caso |

## Totales

| veredicto | filas |
|---|---|
| `allow` | 33 (32 por score 0-20, + `pdf` tras corregirlo) |
| `review` | 31 (11 por score 21-50, 20 por análisis de score ≥51) |
| `deny` | 0 |

## Score ≥51 — por qué son todas `review` y no `deny`

Ninguna de las 20 skills con score ≥51 dispara *solamente* el ruido documentado
(`RP1`, `PE3`, `AE1`, `SC1`, `EA3`); todas tienen reglas adicionales. Inspeccionadas una por una,
los hallazgos fuera de ese set son **falsos positivos por coincidencia de substring**, no
comportamiento real:

| regla | qué matchea realmente |
|---|---|
| `P2` Hidden Instructions | el BOM UTF-8 al inicio de los `.xsd` de ECMA-376; comentarios HTML/XML (`<!-- Progress Bar -->`) |
| `RA2` Session Persistence | la cadena `pList` dentro de `dml-main.xsd` |
| `E2` Env Harvesting | `os.environ.copy()` en los launchers de LibreOffice |
| `P9` / `MP2` Padding / Context Stuffing | el relleno de columnas de las tablas markdown de `SKILL.md` |
| `PE2` Sudo | `sudo apt-get install pandoc` en una línea de prerequisitos documentada |
| `AST3` Dynamic Import | `__import__(import_name)` dentro de un *checker* de dependencias |
| `AST4` subprocess | conversión de documentos en los toolkits `docx`/`pptx`/`xlsx` — su función declarada |
| `P6` Prompt Extraction | substrings `return prompt`, `return rule`, `show instruction`, `## Output rule` |
| `P1` Instruction Override | `hallmark`: la prosa *"this is a system-managed project"*; `ui-ux-pro-max`: una fila de `ux-guidelines.csv` sobre ancho de contenedor |
| `AR3` / `AR2` Anti-Refusal | `insforge`: documentación de políticas RLS de Postgres; `ui-ux-pro-max`: la columna *Don't* de un CSV de guidelines |
| `YR1` / `YR4` YARA | `la-herreria`: su propio `threat-db.yaml` y docs de cookies — es una skill de seguridad, sus firmas matchean contra sí mismas |
| `RA1` Self-Modification | `create-skill` escribiendo `SKILL.md`, que es literalmente su función |
| `LP3` No Declared Permissions | ninguna `SKILL.md` de la biblioteca declara bloque de permisos: hueco sistémico de metadata, no una amenaza por skill |

`LP3` afecta a 14 skills por la misma causa. Vale la pena resolverlo de raíz (declarar permisos en
las `SKILL.md`) en vez de arrastrar un waiver por fila.

## Hallazgo real — `contenido/comunidad/pdf`

**El único hallazgo genuino del set, y puntuaba 22** (`review` por score). El mapeo por score solo
lo habría promovido en silencio.

`SKILL.md`, bajo *"Auto-install if not present (agent should do this automatically)"*:

```python
subprocess.run(
    ["sh", "-c", "curl --proto '=https' --tlsv1.2 -fsSL https://drop-sh.fullyjustified.net | sh"],
    check=True
)
```

y en la rama Windows del mismo bloque:

```python
"iex ((New-Object System.Net.WebClient).DownloadString('https://drop-ps1.fullyjustified.net'))"
```

SkillSpector marcó `SC2` sobre la rama Unix; **la rama Windows no la detectó**. Los dominios son los
oficiales de Tectonic, pero el patrón —ejecución de código remoto iniciada por el agente sin
intervención humana— es lo que el Skill Gate existe para frenar.

**Corregido en este PR:** el bloque se reemplazó por `check_tectonic()`, que sólo detecta y devuelve
el comando de instalación para que lo corra el usuario, siguiendo el patrón de `insforge-cli`
(prerequisito documentado) y `pptx/scripts/check_env.py` (instalación sólo tras `--install`
explícito). Hash recalculado y promovida a `allow`.

### Otro `SC2`: `insforge-cli`

`curl -L https://fly.io/install.sh | sh` en `references/compute-deploy.md`. Patrón real pero en
prosa de prerequisitos, para que lo corra el usuario. Queda en `review` con waiver.

## `SC8` — obsoleto

`image-pipeline` y `video-pipeline` (ambas `mias`, fuera de estas 64) marcan `SC8` por bytecode
Python. El scan corrió a las 17:40 UTC; el commit `37e5f23` que borró el bytecode y lo agregó a
`.gitignore` es de las 20:38 UTC. No queda `__pycache__` en el repo.

## `skill-scanner`

`mias`, score 100 (`P1` ×18, `AR3` ×8, `YR1`, `YR4`): es el código de detección upstream de
getsentry, que **describe** patrones de ataque sin ejecutarlos. La excepción de FP ya está aprobada
(PR #2) y registrada en `skill-gate.yml`. Se conserva `review` con su waiver; sólo se completó el
`scan_version` que estaba vacío.

## Reproducir

```bash
skillspector scan --no-llm --format json <skill-dir>
./scripts/lint-index.sh
./scripts/index-check.sh
```
