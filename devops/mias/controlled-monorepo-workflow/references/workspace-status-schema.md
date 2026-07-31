# WORKSPACE_STATUS.md — recommended schema

Operational memory of the workspace. Read during RESUME; updated during
CLOSE only when authorized. Facts, decisions, and pendings stay separated.
Never invent values: use (unknown) or (none).

## Schema

```markdown
# WORKSPACE_STATUS

## Identity
- Product or System:
- Workspace Type: monorepo | standalone-repo | git-worktree | external-copy-or-migration
- Repository Path:
- Protected Source: <path or (none)>
- Protected Monorepo: <path or (none)>

## Git state (facts at last close)
- Current Branch:
- Current HEAD:
- Working Tree: clean | dirty (documented below)
- Remote:
- Last Commit: <sha — message>

## Phase state
- Completed Phase:
- Current Gate:
- Validation Results: <check: pass/fail/skipped, one per line>
- Known Issues:
- Pending Decisions:
- Next Authorized Phase:

## Governance
- Allowed Actions:
- Forbidden Actions:
- Push Authorization: NOT AUTHORIZED | authorized for <scope> on <date>

## Meta
- Last Updated: <ISO date> by <agent/session>
```

## Generic example (neutral, not project-specific)

```markdown
# WORKSPACE_STATUS

## Identity
- Product or System: Product Alpha
- Workspace Type: external-copy-or-migration
- Repository Path: C:\Dev\alpha-extract
- Protected Source: C:\Dev\alpha-original
- Protected Monorepo: C:\Dev\company-monorepo

## Git state (facts at last close)
- Current Branch: feature/module-extract
- Current HEAD: a1b2c3d
- Working Tree: clean
- Remote: (none)
- Last Commit: a1b2c3d — MODULE-EXTRACT-2B: isolate billing module

## Phase state
- Completed Phase: MODULE-EXTRACT-2B
- Current Gate: READY_FOR_MODULE-EXTRACT-2C
- Validation Results:
  - typecheck: pass
  - lint: pass
  - tests: pass (42/42)
  - build: pass
- Known Issues: (none)
- Pending Decisions: shared utils location (REQUIRES_DECISION)
- Next Authorized Phase: MODULE-EXTRACT-2C

## Governance
- Allowed Actions: edit src/billing/**, update its tests
- Forbidden Actions: touch protected paths, push, dependency changes
- Push Authorization: NOT AUTHORIZED

## Meta
- Last Updated: 2026-07-16 by claude-code session
```
