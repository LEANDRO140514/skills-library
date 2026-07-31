# CLOSE and HANDOFF workflows

## CLOSE — step by step

1. Stop new work. No new features, no new refactors from this point.
2. Run `scripts/workspace-close.*` and show the evidence.
3. Scope review: every change in the diff maps to the authorized scope.
   Out-of-scope change → BLOCKED_BY_SCOPE_VIOLATION or REQUIRES_DECISION.
4. Run VALIDATE (see execution-governance.md) if not already run on the
   final state.
5. Update operational memory ONLY if authorized: WORKSPACE_STATUS.md per the
   schema (workspace-status-schema.md) with facts, decisions, and pendings
   clearly separated. Never invent data. Never mark an omitted obligation as
   "deferred by design".
6. Commit ONLY if the phase authorizes it:
   - Before: `git status --short`, `git diff --stat`, `git diff` (shown).
   - Scope-only staging: add the specific files, never `git add -A` blindly.
   - After: `git rev-parse --short HEAD`, `git status --short`,
     `git log --oneline -5`, `git remote -v` (shown).
7. NO push unless the user expressly authorized push for this phase.
8. Verify protected sources untouched: no writes outside the workspace.
9. Produce the close report: phase, scope, changes, validation results,
   known issues, pending decisions, severity-classified findings.
10. Generate the NEXT_SESSION_BOOTSTRAP block (below).
11. Emit exactly one final gate: `READY_FOR_<NEXT_PHASE>`,
    `READY_FOR_REINTEGRATION_PLANNING`, `REQUIRES_DECISION`, or
    `BLOCKED_BY_<REASON>`.

## NEXT_SESSION_BOOTSTRAP block

Emit at the end of every CLOSE and HANDOFF, fenced exactly like this, so the
user can paste it or keep it in WORKSPACE_STATUS.md. Fill with real values;
use `(none)` or `(unknown)` rather than inventing.

```
=== NEXT_SESSION_BOOTSTRAP ===
Workspace: <path>
Product/System: <name>
Workspace Type: <classification>
Branch: <branch>
HEAD: <short sha>
Last Commits: <up to 3, oneline>
Completed Phase: <phase name>
Gate: <final gate emitted>
Known Issues: <list or (none)>
Pending Decisions: <list or (none)>
Protected Sources: <paths or (none)>
Next Authorized Phase: <name or (awaiting instruction)>
Files To Read First: <ordered list>
Forbidden Actions: <list>
First Command: scripts/workspace-preflight.<sh|ps1>
=== END_BOOTSTRAP ===
```

## HANDOFF

Portable context for another agent or session. Contains everything in
NEXT_SESSION_BOOTSTRAP plus, when relevant: architecture summary in 5 lines
or fewer, validation status per check, and the exact phase instruction that
was completed. HANDOFF is read-only: it never commits, never updates files
unless the user asks to persist it (then write it to a path the user names,
inside the workspace).
