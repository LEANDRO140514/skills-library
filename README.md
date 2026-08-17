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

## Guiding Principle

> The library is the registry of governed capability.
> The router decides.
> Discovery finds.
> Creation creates and evaluates.
> Governance controls how capability becomes canonical and deployable.
