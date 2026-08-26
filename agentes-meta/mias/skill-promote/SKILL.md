---
name: skill-promote
description: Promote a validated skill to the governed library. Use when asked to
  "promote a skill", "merge a skill to main", "register a skill in the index", or
  "fill the INDEX row for a skill". Covers checklist, canonical hash, and row format.
  Does NOT deploy to any runtime.
allowed-tools: Read, Grep, Glob, Bash
---

# Skill Promote

Promote a validated skill to `skills-library/main` by preparing a PR that passes both the Skill Gate (security) and the Promote Check (index integrity).

**Promote != deploy.** Merging to main is not installation in any runtime.

## When to use

- A skill exists in an isolated worktree and has passed (or been waived through) the Skill Gate.
- You need to open the promotion PR with the correct `_INDEX.csv` row.
- You need to verify a row is correct before opening or after a Promote Check failure.

## Pre-promotion checklist

Before opening the PR:

- [ ] Skill Gate passed on this skill (or `scan_verdict=review` with `scan_waiver`)
- [ ] `SKILL.md` is committed in the PR branch (hash requires the committed blob)
- [ ] `ruta_biblioteca` is relative: `categoria/mias_o_comunidad/nombre` — no `C:\`, no leading slash
- [ ] `nombre` in the row matches the folder basename exactly
- [ ] `hash_sha256` matches the canonical blob (see below)
- [ ] `scan_tool`, `scan_version` present if `scan_verdict` is set
- [ ] `scan_verdict=review` → `scan_waiver` explains why
- [ ] `mias_o_comunidad=comunidad` → `scan_verdict` is not empty
- [ ] `scan_verdict=deny` → skill must be under `_archivo/` with `razon_archivo`

## Canonical hash

`hash_sha256` must be the SHA-256 of the content Git stores, not the working-tree file.
On Windows, Git may store LF while the file has CRLF — they produce different hashes.

Compute the correct hash after staging/committing:

```bash
git cat-file blob HEAD:categoria/mias_o_comunidad/nombre/SKILL.md \
  | python3 -c "import sys,hashlib; print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest().upper())"
```

Or use the local check script (requires `python3` and `git`):

```bash
./scripts/index-check.sh categoria/mias_o_comunidad/nombre
```

## _INDEX.csv row format

Columns in order (UTF-8 BOM + CRLF, all fields quoted):

| Column | Value |
|---|---|
| `nombre` | folder basename of the skill |
| `categoria` | top-level dir (backend, contenido, agentes-meta, …) |
| `mias_o_comunidad` | `mias` or `comunidad` |
| `origen` | upstream source or `claude=<path>` |
| `ruta_original` | original source path |
| `hash_sha256` | canonical SHA-256 (see above), uppercase hex |
| `fecha_modificacion` | last modification date/time |
| `confianza` | `alta`, `media`, or `baja` |
| `ruta_biblioteca` | **relative** path from repo root (e.g. `agentes-meta/mias/skill-promote`) |
| `razon_archivo` | empty unless archived |
| `tipo` | `instruccion` |
| `scan_tool` | `skillspector` (or empty if not yet scanned) |
| `scan_score` | raw numeric score from gate CI run |
| `scan_date` | ISO date `YYYY-MM-DD` |
| `scan_verdict` | `allow`, `review`, `deny`, or empty |
| `scan_version` | e.g. `v2.9.6` |
| `scan_report` | path or `ci:<run-id>` |
| `scan_waiver` | explanation if `scan_verdict=review` |

`ruta_biblioteca` must be relative. Absolute paths with `C:\` are legacy and will be normalized by tooling, but new rows must use relative paths.

## Promote Check

The `promote-check.yml` CI job runs automatically on every PR to `main` that touches `SKILL.md`, `scripts/`, or `_INDEX.csv`. It verifies all 8 checks above.

CI does not write `_INDEX.csv`. The PR author fills the row; CI verifies it.

Green CI + human merge = promote.
