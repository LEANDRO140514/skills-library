# Algorithmus Skills Library

Biblioteca gobernada de Skills reutilizables para los agentes y constructores del ecosistema Algorithmus.

Este repositorio es la **fuente de verdad** de las capacidades curadas. Las copias instaladas en runtimes como `~/.claude/skills/` son deployments; no son la fuente canónica.

## Start Here — usar Skills Library en el trabajo real

Esto es una **aduana de capacidades**, no un catálogo para explorar. La filosofía completa está en
[docs/SKILLS_PHILOSOPHY.md](docs/SKILLS_PHILOSOPHY.md); esta sección es el **cómo se usa**.

**Regla base:** el trabajo real hace surgir una necesidad → primero preguntás a esta biblioteca →
sólo si no la cubre salís al ecosistema → sólo si nadie lo resolvió, se construye. Buscar afuera es
refrescar la perspectiva, no vivir cazando Skills.

**Si no hace falta ninguna Skill para la tarea, hacé la tarea.** No todo trabajo necesita una Skill,
y no se inventa una para un caso aislado.

### Si sos humano

1. Estás haciendo algo real y surge una tarea, o falta una capacidad.
2. No abras Internet por reflejo.
3. Preguntá primero a Skills Library: `./scripts/find-skills.sh <nombre>` o `--query "<texto>"`.
4. Si hay una capacidad gobernada adecuada (`allow` / `review`), usala.
5. Si no existe, entonces se puede buscar afuera.
6. Si afuera hay algo adecuado, entra como **candidato** (no como confiable): pasa Skill Gate + Promote.
7. Si genuinamente no existe (`not_found`), recién ahí se puede construir con `skill-creator`.
8. Promover una Skill **no** la despliega — el deployment es una autorización aparte.

### Si sos agente

1. Entendé la tarea e identificá qué capacidad necesita — si es que necesita alguna.
2. ¿Ya está activa en tu contexto/runtime? Usala y listo.
3. Si no, resolvé por la vía gobernada: `skill-router` (razonamiento) → `find-skills` (`scripts/find-skills.sh`).
4. Respetá el `status` devuelto (tabla abajo). **`blocked` no es `not_found`.**
5. No saltes a GitHub / web / `npm` / marketplaces de plugins.
6. No instales capacidades externas por iniciativa propia.
7. No construyas una Skill hasta un `not_found` genuino.
8. Usá sólo las capacidades que la tarea necesita — nada "por si acaso".
9. Si governance bloquea la resolución, pará y reportalo; no busques un atajo.

### `status` — salida de `find-skills`

| status | significado | qué hacer |
|---|---|---|
| `allow` | `mias` (no `deny`, no archivada), o `comunidad` con `scan_verdict=allow` | usar / cargar |
| `review` | `scan_verdict=review` **con** `scan_waiver` | usar, pero es `needs_review` — leé el waiver primero |
| `blocked` | ruta bajo `_archivo/`, `deny`, `review` sin waiver, o `comunidad` sin scan | **no usar** → `BLOCKED_BY_GOVERNANCE`. Si es una ruta `_archivo/`, mostrá el `razon_archivo` de `_INDEX.csv` |
| `unindexed` | carpeta en disco sin fila en `_INDEX.csv` | no usar; la promoción agrega la fila |
| `not_found` | ningún match de nombre | único status que habilita `skill-creator` |

`find-skills` sale con código `0` si al menos un resultado es `allow`/`review`, y `2` en cualquier otro caso.

### If you want to…

| Objetivo | Ir a |
|---|---|
| Entender la filosofía | [docs/SKILLS_PHILOSOPHY.md](docs/SKILLS_PHILOSOPHY.md) |
| Decidir qué capacidad maneja una tarea | `skill-router` (Skill de razonamiento) |
| Resolver una capacidad concreta | `./scripts/find-skills.sh` |
| Cargar skills gobernadas a un proyecto/runtime | `./scripts/load-skills.sh` (hoy: perfil `dev`) |
| Emitir un índice para `AGENTS.md` / `.goosehints` | `./scripts/emit-context.sh` |
| Validar una Skill (seguridad) | `./scripts/scan-skills.sh` |
| Verificar integridad del registro | `./scripts/index-check.sh` · `./scripts/lint-index.sh` |
| Crear una Skill que falta | `skill-creator` — sólo tras `not_found` genuino |
| Desafiar / evolucionar el arsenal | `super-samurai-evolution` (puede concluir `NO CHANGE`) |

## Filosofía

La doctrina canónica está en **[docs/SKILLS_PHILOSOPHY.md](docs/SKILLS_PHILOSOPHY.md)**. Léela antes de agregar, buscar o construir capacidades.

En una línea: **work-driven, local-first, externally refreshed, governed.**

- **Work-driven** — el trabajo real determina qué Skills necesitamos; la biblioteca no determina qué trabajo hacemos. No coleccionamos Skills.
- **Local-first** — se resuelve primero contra lo ya activo y contra esta biblioteca gobernada (`_INDEX.csv`), que es la fuente de verdad.
- **Externally refreshed** — salir al ecosistema externo ocurre **por necesidad**, no como *discovery* permanente; preferimos una solución probada antes de construir la propia.
- **Governed** — toda capacidad externa entra como **candidata**, no como *trusted*: pasa Skill Gate + Promote, y promover ≠ desplegar.

El **Super Samurai** es el crítico externo del arsenal: revisa periódicamente cómo trabajamos y puede concluir legítimamente **NO CHANGE**. Pekín preserva la experiencia; el Samurai combate la complacencia.

## Uso por proyecto y por tarea

### Por proyecto — al empezar

Un proyecto **no** copia toda la biblioteca. Un proyecto:

1. sabe dónde está la fuente canónica (este repo);
2. incorpora la **Capability Policy** (abajo) en su `AGENTS.md` / `CLAUDE.md` o equivalente;
3. da acceso a la resolución gobernada (`skill-router` / `find-skills`) según lo que soporte el runtime;
4. carga sólo lo necesario, o un **perfil gobernado** (hoy sólo existe `dev`) — nunca "todo por si acaso";
5. mantiene Skills Library fuera del dominio funcional del producto;
6. trata cualquier copia local como **deployment**, no como fuente;
7. puede cambiar de agente/orquestador sin perder la doctrina.

```
PROJECT
  ├── AGENTS.md / CLAUDE.md  ──►  Capability Policy (apunta a este repo)
  ├── runtime / agents
  └── acceso gobernado a Skills Library      (NO: copiar las 100+ skills al repo)
```

Principio: **minimum necessary capability set** — no precargar capacidades "por si acaso".

#### Capability Policy — plantilla

```text
CAPABILITY POLICY
- Skills Library (https://github.com/LEANDRO140514/skills-library) es la fuente
  gobernada de capacidades reutilizables. Doctrina: docs/SKILLS_PHILOSOPHY.md.
- Usá primero la capacidad ya activa.
- Si no, resolvé por la biblioteca gobernada (skill-router / find-skills).
- El discovery externo ocurre sólo tras un miss local real.
- Las capacidades externas entran como candidatas, nunca como confiables.
- No instales Skills directamente.
- Sólo un NOT_FOUND genuino habilita crear una Skill.
- Usá sólo las capacidades que la tarea necesita.
- Promote y Deploy son aprobaciones separadas.
- Si la tarea no necesita una Skill, hacé la tarea.
```

Apunta al repo y a la doctrina; no dupliques la doctrina entera dentro del proyecto.

### Por proyecto — uno que ya existe

1. No muevas ni copies Skills al repo indiscriminadamente.
2. Leé las instrucciones existentes del proyecto.
3. Agregá la Capability Policy **sin** romper políticas previas.
4. Elegí un modo de integración soportado (ver [Uso → Tres modos](#tres-modos-de-consumir-la-biblioteca)).
5. Hacé `--dry-run` antes de cualquier deployment.
6. No conviertas una copia de runtime en fuente de verdad.
7. Empezá tarea por tarea.

### Por tarea — flujo canónico

```
TASK
  └─ ¿Qué capacidad necesita?  (si necesita alguna)
       ├─ ya activa ─────────────► USAR
       └─ no ─► skill-router ─► find-skills
                 ├─ allow ────────► USAR
                 ├─ review ───────► leer waiver ─► USAR si está gobernado
                 ├─ blocked ──────► STOP · BLOCKED_BY_GOVERNANCE  (no es not_found)
                 ├─ unindexed ────► no usable aún (falta promoción)
                 └─ not_found ────► discovery externo (si la policy lo permite)
                       ├─ hay algo ─► candidato ─► VALIDATE ─► PROMOTE ─► (deploy aparte) ─► USAR
                       └─ nada ─────► skill-creator ─► candidato ─► VALIDATE ─► PROMOTE ─► (deploy aparte)
```

Una ruta `_archivo/` sale como `blocked`: mostrá su `razon_archivo` y sólo seguí tras confirmación explícita.

### Cuándo salir afuera

Sólo cuando: hay una necesidad real · la capacidad no está activa · la biblioteca no la resuelve ·
no es simplemente `blocked` · no está archivada pendiente de decisión · el resultado es `not_found`
genuino (o el flujo gobernado autoriza el discovery).

Orden: **NEED → INTERNAL → EXTERNAL → BUILD.** No: `INTERNET → HYPE → INSTALL`.

### Cuándo construir

Construir es el último recurso. Una Skill nueva tiene sentido cuando la capacidad realmente no
existe de forma adecuada, el problema es reutilizable, hay un flujo no obvio que vale la pena
conservar, la consistencia importa, hay un resultado verificable, y aporta valor más allá de una
ejecución aislada. `skill-creator` es dueño de la creación y la evaluación; acá sólo se explica
cuándo se llega hasta ahí.

### Modificar una Skill existente

```
NECESIDAD DE CAMBIO
  └─ skills-library canónico
       └─ branch/worktree aislado ─► editar ─► Skill Gate ─► Promote Check
            └─ aprobación humana ─► main ─► (deployment aparte)
```

`super-samurai-evolution` es el **crítico externo** del arsenal, no un requisito para modificar una
Skill: se invoca cuando querés que una mirada no complaciente cuestione el arsenal, y puede concluir
`NO CHANGE`.

## No es sólo para programación

El protocolo es **universal**. Aplica a cualquier trabajo repetible que se beneficie de una
capacidad: desarrollo, arquitectura, DevOps, seguridad, diseño UI/UX, contenido, imágenes, video,
documentos, investigación, marketing, CRM, GHL, WhatsApp, automatización, análisis de datos,
operaciones, QA, revisión, despliegue, gobierno multiagente.

No hay —ni se promete— una Skill por categoría. La regla: **el protocolo es universal; el arsenal
crece sólo por trabajo real.**

## Agent Capability Contract

Reglas mínimas para cualquier agente que consuma esta biblioteca (copiables a un `AGENTS.md`):

1. Do the work; do not browse Skills recreationally.
2. Use already-active capability when adequate.
3. Otherwise resolve through the Algorithmus Skills Library.
4. Local/governed resolution precedes external discovery.
5. Respect `allow` / `review` / `blocked` / `unindexed` / `not_found` (and the `razon_archivo` behind an `_archivo/` block).
6. `blocked` != `not_found`.
7. External Skills are candidates, never trusted automatically.
8. Do not directly install an external Skill.
9. Find before build.
10. Only a genuine `not_found` may reach `skill-creator`.
11. Use the minimum capability set the task requires.
12. Promotion requires governance.
13. Deployment requires separate authorization.
14. Runtime copies are not canonical.
15. Do not modify Skills Library from a consuming project.
16. If the task does not need a Skill, do the task without inventing one.

Runtime-agnóstico: Claude Code, OpenCode, kimchi, Codex, Kimi, Cursor, Goose, Warp y cualquier
orquestador son **consumidores**. La doctrina no depende de ninguno.

### Agent quickstart — entrar a un proyecto por primera vez

```
Estás trabajando en PROJECT-X.
Antes de resolver una tarea que parece necesitar una capacidad reutilizable:
  1. inspeccioná las instrucciones del proyecto (AGENTS.md / CLAUDE.md / equivalente);
  2. identificá la capacidad requerida;
  3. usá la vía de resolución gobernada de Algorithmus (skill-router → find-skills);
  4. cargá/leé sólo la Skill resuelta;
  5. seguí con la tarea;
  6. si la resolución devuelve `blocked`, frená la adquisición de capacidad y reportalo;
  7. si es `not_found` genuino, el discovery externo puede empezar según la policy.
```

### Human quickstart — "tengo que hacer X"

```bash
# 1. Buscar capacidad
./scripts/find-skills.sh <nombre>
./scripts/find-skills.sh --query "<texto>"

# 2. Interpretar el `status` (ver tabla en «Start Here»)
# 3. allow/review -> usar (review: leer el scan_waiver primero)
# 4. blocked      -> STOP (governance) · unindexed -> falta promoción
# 5. not_found    -> recién ahí, discovery externo y, si nada sirve, skill-creator
```

## Arquitectura

    task
      |
      v
    skill-router
      |
      +-- capability already active?
      |      +-- yes -> use it
      |
      +-- no -> find-skills
                  |
                  +-- installed capability
                  +-- active skills-library entry
                  +-- archived entry -> confirmation
                  +-- external candidate -> review
                  +-- genuine NOT_FOUND
                           |
                           v
                      skill-creator
                           |
                           v
                controlled-monorepo-workflow
                isolation / validation / review
                           |
                           v
                    explicit approval
                           |
                           v
                  skills-library promotion
                           |
                           v
                separate deployment approval

## Source of Truth

The governed repository is the source of truth.

Typical canonical checkout:

    C:\skills-library

Runtime copies such as:

    C:\Users\<user>\.claude\skills\

are deployments of governed Skills. Changes made directly to a runtime copy must not silently become canonical.

The normal direction is:

    isolated worktree
          |
          v
      validate
          |
          v
    explicit approval
          |
          v
    skills-library / main
          |
          v
      deployment

## Repository Structure

    skills-library/
    ├── _INDEX.csv
    ├── agentes-meta/
    ├── backend/
    ├── contenido/
    ├── data-n8n/
    ├── devops/
    ├── diseno/
    ├── seguridad/
    └── _archivo/

Inside the active categories, Skills are generally classified as:

- `mias/` — Skills authored or governed directly by Algorithmus.
- `comunidad/` — Skills originating from external/community sources curated into the library.
- `_archivo/` — Skills intentionally removed from the normal active resolution path.

Archived entries may represent cases such as `duplicado`, `descartado` or `pospuesto`.

An archived Skill must not be treated as a normal active result. Its `razon_archivo` must be surfaced before any possible activation.

## _INDEX.csv

`_INDEX.csv` is the governed registry of the library.

Its current metadata includes:

- `nombre`
- `categoria`
- `mias_o_comunidad`
- `origen`
- `ruta_original`
- `hash_sha256`
- `fecha_modificacion`
- `confianza`
- `ruta_biblioteca`
- `razon_archivo`
- `tipo`

### ruta_biblioteca

`ruta_biblioteca` is authoritative for locating the physical Skill in the canonical library.

Do not reconstruct a path from `categoria`, `mias_o_comunidad`, or `nombre`.

Always resolve the actual library location from `ruta_biblioteca`.

## Skill Resolution Responsibilities

### skill-router

`skill-router` is the capability-resolution control plane.

It decides what should handle a task and coordinates the governed resolution sequence.

It does not implement discovery, skill creation, Git/worktree mechanics, promotion, or deployment itself.

### find-skills

`find-skills` owns discovery.

Resolution is local-first:

1. Check whether the capability is already active.
2. Search `_INDEX.csv`.
3. Resolve the Skill through `ruta_biblioteca`.
4. Handle `_archivo` entries according to `razon_archivo`.
5. Only when authorized local resolution is exhausted, continue to external discovery.

A stage blocked by governance is not equivalent to `NOT_FOUND`.

    local miss + external discovery blocked
    =
    BLOCKED_BY_GOVERNANCE

not:

    NOT_FOUND

### skill-creator

`skill-creator` owns creation and evaluation of genuinely missing capabilities.

Creation is reached only after governed discovery has produced a genuine `NOT_FOUND` and the user explicitly approves creating a new Skill.

### controlled-monorepo-workflow

`controlled-monorepo-workflow` owns development governance, including:

- isolated workspaces/worktrees
- writable vs. read-only authority
- PREFLIGHT
- EXECUTE
- VALIDATE
- CLOSE
- Git mutation governance
- reintegration
- promotion
- deployment authorization boundaries

## Governance Principles

The library follows these rules:

- Develop changes in an isolated writable workspace when appropriate.
- Treat the canonical checkout as the governed source of truth.
- Do not silently mutate global runtime installations.
- Do not automatically create a Skill merely because discovery could not run.
- Do not automatically promote a newly created Skill.
- Do not automatically deploy a promoted Skill.
- Require explicit authorization at write, promotion, deployment, and destructive Git boundaries.
- Preserve unrelated or pre-existing working-tree changes.
- Prefer explicit paths over broad operations such as `git add .`.

## Registry Hash Semantics

`hash_sha256` represents the SHA-256 of the **canonical Git content of `SKILL.md`**, not the platform-specific bytes of a materialized working tree.

This distinction matters on systems where Git performs line-ending conversion.

For example:

    Git canonical content     LF
    Windows working tree      CRLF

Both can represent the same Git content while producing different physical-file SHA-256 values.

Therefore, governed registry verification should hash the content stored by Git, conceptually:

    git cat-file blob HEAD:path/to/SKILL.md
            |
            v
         SHA-256

Do not define registry identity using a Windows `Get-FileHash` result alone when line-ending conversion may be active.

## Promotion and Deployment

Promotion and deployment are separate operations.

    validated candidate
          |
          v
    promotion to skills-library
          |
          v
    _INDEX.csv integrity
          |
          v
    commit / reintegration
          |
          v
    origin/main
          |
          v
    separate deployment authorization
          |
          v
    agent runtime

A successful promotion does not automatically authorize deployment.

## Current Skill Resolution Protocol

The governed Skill Resolution Protocol v5 is centered on:

- `agentes-meta/mias/skill-router/`
- `agentes-meta/comunidad/find-skills/`
- `agentes-meta/comunidad/skill-creator/`
- `devops/mias/controlled-monorepo-workflow/`

The protocol is deliberately modular: each Skill owns one responsibility instead of duplicating the implementation of the others.

## Validate

Every skill that touches `SKILL.md` or `scripts/` in a PR must pass the Skill Gate before merging.

### Scanner

**SkillSpector v2.9.6** (NVIDIA, static analysis, `--no-llm`).

Pinned version: `git+https://github.com/NVIDIA/SkillSpector.git@v2.9.6`

A version bump is its own dedicated PR — never a silent in-place update.

Local run:

    ./scripts/scan-skills.sh <skill-dir> [<skill-dir> ...]

Noise baseline for `comunidad` product skills (`--no-llm`): [docs/validate-baseline.md](docs/validate-baseline.md).

The 5 Jewel skills in that baseline now carry `scan_*` in `_INDEX.csv` and are no
longer "comunidad ciega": `add-emails` + `add-payments` → `allow`; `add-mobile`,
`add-ui-kit`, `supabase` → `review` with a `scan_waiver` for the PE3/RP1 false
positives approved 2026-08-28 (`scan_report` = the baseline doc).

### Threshold

| Condition | CI result | scan_verdict | Next step |
|---|---|---|---|
| 0 critical, score 0–20 | pass | `allow` | Short review + promote |
| 0 critical, score 21–50 | pass | `review` | Sentry skill-scanner review + explicit OK or `scan_waiver` |
| ≥1 critical **or** score ≥ 51 | **fail** | `deny` | Fix before merge; skill goes to `_archivo/` if not fixable |

**Fail = critical finding or score ≥ 51 (DO NOT INSTALL per SkillSpector). Score 50 without critical does not fail the PR.**

SARIF results go to the Security tab (Code Scanning). No public artifact.

### Result → _INDEX.csv mapping

`scan_verdict` values: `allow` | `review` | `deny` | *(empty — not yet scanned)*

- `find-skills` **must not** resolve a `comunidad` skill with `deny`, no scan, or empty `scan_verdict`.
- `mias` skills with `review` + `scan_waiver` are resolvable for meta-skills only (see below).
- `mias` skills go through the same gate — no auto-trust for first-party skills.
- `antigravity.zip` stays in `_archivo/` unscanned; it is not resolvable.

### find-skills respects scan_verdict

`find-skills` is not a grep of names. Inside this repo it resolves through
`scripts/find-skills.sh`, which reads `_INDEX.csv` (it never writes it) and never
calls SkillSpector. It returns a `status` per matching row:

- `allow` — `mias` (not `deny`, not archived), or `comunidad` + `scan_verdict=allow`. Resolvable.
- `review` — `scan_verdict=review` **with** a non-empty `scan_waiver`. Resolvable but `needs_review`; the caller must surface the waiver, not load it as `allow`.
- `blocked` — `_archivo/` path, `scan_verdict=deny`, `review` without a waiver, or **`comunidad` with empty/absent `scan_verdict`**. Not resolvable → `BLOCKED_BY_GOVERNANCE`, never `NOT_FOUND`.
- `unindexed` — folder on disk with no row. Not resolvable; promotion adds the row.
- `not_found` — no name match anywhere. The only status that may lead to `skill-creator`.

**Comunidad without a scan is not loaded.** A `comunidad` skill stays `blocked`
until the Skill Gate scores it and its row carries `scan_verdict` (+ `scan_waiver`
if `review`). Exit code: `0` when a result is `allow`/`review`, `2` otherwise.

### Initial ingestion exception (meta-skills)

A meta-skill entering the library for the first time may carry `scan_verdict=review` + a `scan_waiver` explaining why a full baseline is pending. The first PR that subsequently touches the skill must include a complete scan result — `scan_score`, `scan_version`, `scan_report` — before the waiver can be cleared.

`find-skills` treats `review + scan_waiver` as resolvable (marked `needs_review`) for `agentes-meta/` entries — `mias` and `comunidad` alike. Product-category `comunidad` skills (backend, contenido, diseño, …) still require `scan_verdict=allow`, or `review` with an explicit per-skill waiver, before they resolve.

### ECC candidates (wave 1)

[ECC](https://github.com/affaan-m/ECC) is treated as **upstream of candidates, not a plugin** — no `/plugin` marketplace, no `ecc@ecc`, no hooks. Skills enter `agentes-meta/comunidad/` one wave at a time and pass VALIDATE + PROMOTE like any other. Each carries an `UPSTREAM.md` (repo, original path, pinned commit SHA, MIT license); `origen` in `_INDEX.csv` is `https://github.com/affaan-m/ECC@<sha>`. Wave 1 (PR, ECC @ `d8e6a51`): `tdd-workflow`, `security-review`, `coding-standards` — SkillSpector `--no-llm` 0 / 0 / 20, all `allow`.

### False positive exceptions

Approved exceptions are implemented as scan-scope exclusions in the gate — not as threshold reductions. The global threshold (score ≥ 51 or any CRITICAL) applies everywhere else.

| Skill | Excluded path | Rule(s) | Reason | Approved |
|---|---|---|---|---|
| `agentes-meta/mias/skill-scanner` | `references/**`, `scripts/**` | YR4, YR1, AR3, LP1, MP3, P1, P2, P6, PE3 | Upstream getsentry reference files and detection script. Both describe and detect attack patterns — they do not perform them (`documentar != atacar`). The scanner's own detection code and reference material are not attack surfaces. Scanned scope: `SKILL.md` only. | PR #2, 2026-08-26 |

To add an exception: open a PR that modifies `.github/workflows/skill-gate.yml` (the `prep` step), adds a row here, and updates `scan_waiver` in `_INDEX.csv` for the affected skill. The exception must name the specific path glob, the rule IDs confirmed as false positive, and the reason.

## Promote

A PR enters `main` only when its `_INDEX.csv` row is complete and correct. The Promote Check enforces this automatically.

**Promote != deploy.** A successful promotion does not install the skill in any runtime.

### Pipeline position

| Gate | Job | What it checks | Who fills data |
|---|---|---|---|
| Validate | `skill-gate.yml` | Security (SkillSpector) | CI writes nothing; human reads score |
| **Promote** | `promote-check.yml` | Index integrity (hash, verdict, fields) | PR author fills `_INDEX.csv` row; CI verifies |
| Deploy | *(separate authorization)* | Runtime installation | Explicit deployment approval |

Both Validate and Promote must pass before a PR that touches `SKILL.md` or `scripts/` can merge. If only `_INDEX.csv` changes, only Promote Check runs.

### Trigger paths

| Path pattern | Validate | Promote |
|---|---|---|
| `**/SKILL.md` | yes | yes |
| `**/scripts/**` (within a skill) | yes | yes |
| `_INDEX.csv` | no | yes |
| `README.md`, workflow files | no | no |

### What the Promote Check verifies

For each skill directory touched in the PR (including skills mentioned in `_INDEX.csv` rows that changed):

| Check | Field | Rule |
|---|---|---|
| a | `SKILL.md` | File exists at the path |
| b | `ruta_biblioteca` | Exactly 1 matching row in `_INDEX.csv` |
| c | `hash_sha256` | Equals SHA-256 of `git cat-file blob HEAD:skill/SKILL.md` |
| d | `scan_verdict` | Must be `allow` or `review` for active skills; `deny` → skill must be in `_archivo/` |
| e | `scan_waiver` | Required when `scan_verdict=review` |
| f | `scan_verdict` (comunidad) | Cannot be empty for `mias_o_comunidad=comunidad` |
| g | `scan_tool`, `scan_version` | Required when `scan_verdict` is set |
| h | `nombre` | Must match the folder basename of `ruta_biblioteca` |

CI only runs checks against skills **touched in the PR** — existing rows with empty `scan_verdict` are not re-validated on every PR.

### Canonical hash

`hash_sha256` is the SHA-256 of the Git blob content (LF line endings), not the working-tree file (which may be CRLF on Windows).

```bash
git cat-file blob HEAD:categoria/mias/nombre/SKILL.md \
  | python3 -c "import sys,hashlib; print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest().upper())"
```

Or use the local script:

```bash
./scripts/index-check.sh categoria/mias/nombre
```

### `ruta_biblioteca` format

Always relative from repo root. No `C:\`, no leading slash.

    agentes-meta/mias/skill-promote     ← correct
    C:\skills-library\agentes-meta\...  ← legacy (tolerated in existing rows, forbidden in new ones)

### Editing `_INDEX.csv` safely

`_INDEX.csv` is the PROMOTE source of truth. It has broken twice from bad
writers (double BOM, a TAB-delimited row). Follow this recipe:

1. Edit with Python only: `open(path, newline="", encoding="utf-8-sig")` to
   read, `newline=""` + `utf-8-sig` (exactly one BOM) to write.
2. Never touch it with PowerShell `Set-Content`, `Out-File`,
   `[IO.File]::WriteAllText`, or `echo >>` — they inject BOMs / CRLF / UTF-16.
3. Delimiter is comma only. Zero tabs anywhere in the file.
4. `hash_sha256` = SHA-256 of the **Git blob** of `SKILL.md`
   (`git cat-file blob HEAD:<path>/SKILL.md`), never `Get-FileHash` of the
   working-tree file (CRLF on Windows → wrong hash).
5. `ruta_biblioteca` is repo-root-relative (see above).
6. Run `./scripts/lint-index.sh` before every push.

### Local index check

```bash
# Canonical-form lint: one BOM, zero tabs, uniform column count
./scripts/lint-index.sh

# Check one skill
./scripts/index-check.sh agentes-meta/mias/skill-promote

# Check all active rows (local use only — CI always passes dirs explicitly)
./scripts/index-check.sh
```

## Uso

Cómo trabajar **con** las skills gobernadas sin depender de ningún chat previo.
Comandos reales; el flujo conceptual está en [Start Here](#start-here--usar-skills-library-en-el-trabajo-real)
y en [Uso por proyecto y por tarea](#uso-por-proyecto-y-por-tarea).

### Tres modos de consumir la biblioteca

| Modo | Cuándo | Herramienta |
|---|---|---|
| **A — Resolución gobernada directa** | el agente lee `C:\skills-library`: consulta, resuelve `ruta_biblioteca`, abre el `SKILL.md` on-demand, no toca la fuente | `scripts/find-skills.sh` (+ `skill-router` como razonamiento) |
| **B — Deployment a un runtime** | el runtime necesita una copia local de las Skills | `scripts/load-skills.sh --profile <p> --target <dir> --apply` |
| **C — Emisión de índice/contexto** | el runtime lee un markdown fijo (`AGENTS.md`, `.goosehints`) y no auto-descubre `SKILL.md` | `scripts/emit-context.sh` |

Modo A depende de que el agente pueda leer archivos del checkout y abrir un `SKILL.md` por su cuenta;
`skill-router` es una Skill de razonamiento, no un ejecutable. Modos B y C sólo necesitan Git Bash + Python.
**Deployment ≠ canónico** en los tres casos.

**Compatibilidad de runtimes (regla durable, no un contrato del repo):**

- Si un runtime hace **auto-discovery** de `SKILL.md` en un directorio, puede consumir capacidades
  gobernadas por esa vía (deployá con Modo B a un directorio que el runtime escanee).
- Si un runtime lee un **archivo fijo** (`AGENTS.md`, `.goosehints`, …), `emit-context.sh` genera el
  índice gobernado en los formatos que soporta hoy (`agents`, `goosehints`).
- Los nombres de runtimes que aparecen en este README son **ejemplos conocidos al momento de
  escribir**, no una garantía de compatibilidad permanente. Verificá cada runtime contra sus
  capacidades actuales.

### Qué es este repo

Una **aduana**, no un marketplace. `_INDEX.csv` es el registro; cada skill entra
por VALIDATE (Skill Gate) + PROMOTE (Promote Check) y queda en su categoría. Las
copias que uses en un runtime (`.claude/skills/`, etc.) son **deployments**, nunca
la fuente canónica. No se instala nada con `/plugin`.

### Setup (Windows)

```bash
git clone https://github.com/LEANDRO140514/skills-library.git C:\skills-library
```

- Los scripts son `.sh`: usá **Git Bash** (no PowerShell, no cmd).
- Necesitan **Python 3**. `find-skills.sh`, `load-skills.sh` y `emit-context.sh` prueban
  `python3` → `python` → `py -3`. `index-check.sh` y `lint-index.sh` invocan `python3`
  directamente: en Windows donde sólo funciona `py -3`, corré su lógica con `py -3` o poné
  un `python3` real en el PATH (ver *Operational gaps* más abajo).
- El Skill Gate local (`scripts/scan-skills.sh`) necesita **SkillSpector** en el PATH:

  ```bash
  uv tool install "git+https://github.com/NVIDIA/SkillSpector.git@v2.9.6"
  ```

  Si `skillspector` quedó en `~/.local/bin`, agregá esa carpeta al PATH de Git Bash.

### Resolver una skill

```bash
./scripts/find-skills.sh <nombre>
./scripts/find-skills.sh --query "<substring>"
```

Devuelve un JSON por fila con un `status` (`allow` · `review` · `blocked` · `unindexed` · `not_found`).
La tabla de qué hacer con cada uno está en [Start Here → `status`](#status--salida-de-find-skills).

### Cargar un perfil a un target explícito

`load-skills.sh` resuelve cada skill del perfil con `find-skills` y copia **solo**
las `allow` / `review`. No asume ningún target: `--target` es obligatorio.

```bash
# Ver qué haría (default):
./scripts/load-skills.sh --profile dev --target /c/skills-dev --dry-run

# Aplicar de verdad, al runtime de este repo:
./scripts/load-skills.sh --profile dev --target /c/skills-library/.claude/skills --apply
```

Copia `SKILL.md` + `UPSTREAM.md` + `*.md` de raíz + `scripts/` + `references/` a
`<target>/<nombre>/`. No hay `--prune`: limpiar copias viejas del target es manual.

**Perfiles hoy: sólo `dev`** = `find-skills`, `skill-promote`, `skill-scanner`, `tdd-workflow`,
`security-review`, `coding-standards`, `controlled-monorepo-workflow` (las 5 skills Jewel **no**
están en ningún perfil). No existen perfiles para marketing / contenido / operaciones / diseño /
etc.: cualquier otro perfil debe definirse y gobernarse antes de poder usarse.

`load-skills.sh` despliega **por perfil**. Hoy **no existe un comando first-class de deployment
gobernado para una sola Skill** (CURRENT LIMITATION — ver *Operational gaps*). Para desplegar una
Skill sola: agregala a un perfil gobernado. Una copia manual puede funcionar técnicamente pero queda
**fuera del flujo de deployment soportado por este repo**, no es el procedimiento recomendado, y
nunca se convierte en source of truth ni en promoción canónica.

`.claude/skills/` está en `.gitignore`: una carga local nunca se commitea.

### Runtimes que no auto-descubren `SKILL.md` (AGENTS.md / .goosehints)

Claude Code y kimchi escanean un directorio de skills solos. OpenCode, Cursor,
Warp o Goose leen **un** markdown fijo. Para esos, `emit-context.sh` genera un
bloque-índice desde `_INDEX.csv` — mismas reglas de gobernanza que `find-skills`
(solo lista `allow` / `review`); el agente abre cada `SKILL.md` on-demand.

```bash
# Bloque para AGENTS.md (OpenCode, Cursor, kimchi, …):
./scripts/emit-context.sh --format agents --profile dev --root ~/skills-library >> AGENTS.md

# Bloque para .goosehints (Block Goose):
./scripts/emit-context.sh --format goosehints --profile dev --root ~/skills-library >> .goosehints
```

`--root` prefija la ruta de cada `SKILL.md` (checkout de la librería, o un
`--target` de `load-skills`); sin `--root` las rutas son relativas a la raíz del
repo. Sin `--profile` lista toda la librería resoluble. Solo escribe a stdout: el
bloque entre `BEGIN/END governed-skills` es un deployment, se **regenera**, no se
edita a mano.

### Programar trabajo con estas skills

Corré Claude Code (u otro agente) **dentro de `C:\skills-library`** para gobernar
la librería, o **dentro del `--target`** donde cargaste el perfil para usar las
skills en otro proyecto. La librería nunca se consume como runtime en sí misma.

### Agregar una skill nueva

```
worktree aislado  ->  Skill Gate (VALIDATE)  ->  Promote Check (PROMOTE)
                  ->  merge a main  ->  ./scripts/load-skills.sh ... --apply
```

Recién después del merge la skill es cargable por perfil.

### DO / DON'T

| DO | DON'T |
|---|---|
| resolver primero (activa → biblioteca → externo) | instalar una Skill de GitHub directamente |
| usar el mínimo de Skills que la tarea necesita | precargar todo "por si acaso" |
| leer el `scan_waiver` antes de usar un `review` | tratar `blocked` como `not_found` |
| preservar la fuente canónica | tratar una copia de runtime como canónica |
| usar `--target` explícito y `--dry-run` primero | copiar `comunidad/` entera a un runtime |
| mantener promoción y deployment como pasos separados | crear una Skill para cada tarea de una sola vez |
| editar `_INDEX.csv` sólo con Python (ver *Editing `_INDEX.csv` safely*) | editarlo con PowerShell `Set-Content` / `Out-File` (rompe BOM/EOL) |
| dejar que las mejoras vuelvan por PR (Skill Gate + Promote) | reintroducir cambios de una copia de runtime a `main` en silencio |
| — | `/plugin install ecc` (ECC es upstream de candidatos, no un plugin) |
| — | modificar Skills Library desde un proyecto consumidor |

### validate vs promote vs load

| paso | script / CI | qué hace | escribe |
|---|---|---|---|
| **validate** | `scripts/scan-skills.sh` · Skill Gate | corre SkillSpector, decide `allow`/`review`/`deny` | nada |
| **promote** | `scripts/index-check.sh` · Promote Check | verifica la fila de `_INDEX.csv` y mergea a `main` | `_INDEX.csv` (por el autor del PR), `main` |
| **load** | `scripts/load-skills.sh --apply` | copia skills ya gobernadas a un `--target` | solo el `--target` |
| **emit-context** | `scripts/emit-context.sh` | índice `AGENTS.md` / `.goosehints` desde `_INDEX.csv` | nada (stdout) |

**load ≠ promote.** `load` nunca toca `_INDEX.csv` ni `main`; solo materializa
una copia de deployment. `emit-context` tampoco escribe: vos rediriges su salida.

### Operational gaps (estado actual, no bloqueantes)

Cosas que la doctrina contempla pero el tooling **todavía no** soporta. No son bugs del README;
son trabajo futuro real.

| Gap | Estado | Efecto |
|---|---|---|
| Perfiles de `load-skills.sh` | sólo `dev` | no hay perfiles gobernados para marketing / contenido / operaciones / diseño / etc. |
| Deployment por Skill individual | NOT YET IMPLEMENTED | no hay comando first-class para desplegar una sola Skill gobernada; hay que agregarla a un perfil. Una copia manual queda fuera del flujo soportado y nunca es canónica |
| `python3` en `index-check.sh` / `lint-index.sh` | hardcoded | fallan en Windows si sólo existe `py -3` (los otros scripts sí prueban `python`/`py -3`) |
| Resolución directa para un agente sin file-tools | limitada | Modo A necesita que el agente lea el checkout y abra un `SKILL.md`; `skill-router` no es ejecutable |
| Cobertura de runtimes | por mecanismo, no por lista | un runtime con auto-discovery de `SKILL.md` consume vía Modo B; uno con archivo fijo, vía `emit-context` (`agents` / `goosehints`); cualquier otro mecanismo no está cubierto. Los nombres en este README son ejemplos conocidos, no una garantía permanente |

## Guiding Principle

> The library is the registry of governed capability.
> The router decides.
> Discovery finds.
> Creation creates and evaluates.
> Governance controls how capability becomes canonical and deployable.
