# AGENTS.md — optional generic template

Interoperable repository authority, readable by any agent. Offer it when the
user asks; never create it in a project uninvited.

```markdown
# AGENTS.md

## Scope of this repository
<one paragraph: what this repo/workspace is and what it is not>

## Protected surfaces
- Protected source (read-only): <path or (none)>
- Protected monorepo (read-only): <path or (none)>

## Ground rules for agents
- Work only within the scope authorized for the current phase.
- No push without explicit authorization.
- No destructive git operations (reset --hard, clean, force push).
- Validate with the project's own scripts before any commit.
- On drift or conflicting authorities: stop and report; never self-correct.

## Project commands
- install: <command>
- typecheck: <command>
- lint: <command>
- test: <command>
- build: <command>

## Session protocol
- Start: run scripts/workspace-preflight.<sh|ps1>; emit a recovery gate.
- End: run scripts/workspace-close.<sh|ps1>; emit NEXT_SESSION_BOOTSTRAP.
```
