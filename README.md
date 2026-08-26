# Algorithmus Skills Library

Biblioteca gobernada de Skills reutilizables para los agentes y constructores del ecosistema Algorithmus.

Este repositorio es la **fuente de verdad** de las capacidades curadas. Las copias instaladas en runtimes como `~/.claude/skills/` son deployments; no son la fuente canónica.

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

### Initial ingestion exception (meta-skills)

A meta-skill entering the library for the first time may carry `scan_verdict=review` + a `scan_waiver` explaining why a full baseline is pending. The first PR that subsequently touches the skill must include a complete scan result — `scan_score`, `scan_version`, `scan_report` — before the waiver can be cleared.

`find-skills` (when implemented) treats `review + scan_waiver` as resolvable for `agentes-meta/mias/` entries only, not for product-category `comunidad` skills.

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

### Local index check

```bash
# Check one skill
./scripts/index-check.sh agentes-meta/mias/skill-promote

# Check all active rows (local use only — CI always passes dirs explicitly)
./scripts/index-check.sh
```

## Guiding Principle

> The library is the registry of governed capability.
> The router decides.
> Discovery finds.
> Creation creates and evaluates.
> Governance controls how capability becomes canonical and deployable.
