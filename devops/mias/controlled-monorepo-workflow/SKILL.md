---
name: controlled-monorepo-workflow
description: Govern agent work on monorepos, standalone repositories, external development copies, git worktrees, extracted modules, and temporary migration workspaces. Use this skill WHENEVER the user needs to recover context of a repository or workspace, resume work, start a controlled work phase, run repository preflight, protect a monorepo or external source, work in an isolated copy, validate changes before commit, close a phase, generate a handoff, prepare a selective reintegration, or investigate branch/HEAD/working-tree drift. Trigger on requests like "resume this workspace", "recover project context", "start the next phase", "run repository preflight", "close this phase", "prepare the handoff", "validate before commit", "plan reintegration into the monorepo" — in any language. Also applies when a session opens inside any git repository containing WORKSPACE_STATUS.md, AGENTS.md, SOURCE_SNAPSHOT.md, or phase reports.
---

# Controlled Monorepo Workflow

Deterministic protocol for agents working on repositories across sessions.
The agent may change. The protocol does not.

## Core model

```
MONOREPO / INSTITUTIONAL REPOSITORY   WORKSPACE / ISOLATED COPY
→ consolidated code                   → development
→ accepted architecture               → experimentation
→ source of truth                     → refactoring / migration
→ governed history                    → validation before integration
→ READ-ONLY during isolated work      → the ONLY writable surface
```

By default: only the active workspace is modifiable. External original
sources, protected monorepos, and reference repositories are read-only.
Any write outside the active workspace requires explicit user authorization.

## Classification is two-dimensional

Structure (physical, script-detected: standalone-repo | formal-monorepo |
worktree | non-git-folder) and role (authority-assigned:
institutional-source-of-truth | external-development-workspace |
ordinary-repository | reference-source) are reported separately. Role is
never inferred from folder structure alone. Remote state is reported with
cached-reference language only; never claim sync with a remote service
without a verified fetch (details: references/resume-workflow.md).

## Choosing the mode

Pick exactly one mode per request. If the user's intent is ambiguous, default
to RESUME (read-only) and state the chosen mode in the first line of output.

| User intent | Mode | Read reference first |
|---|---|---|
| Recover context, resume, "where were we" | RESUME | references/resume-workflow.md |
| Verify environment before a phase | PREFLIGHT | references/resume-workflow.md |
| Implement the authorized phase | EXECUTE | references/execution-governance.md |
| Check work before commit | VALIDATE | references/execution-governance.md |
| End the phase, commit if authorized | CLOSE | references/close-phase-workflow.md |
| Produce portable context for another agent/session | HANDOFF | references/close-phase-workflow.md |
| Plan moving work into the monorepo | REINTEGRATE | references/reintegration-workflow.md |
| Investigate without touching anything | AUDIT | references/reintegration-workflow.md |

RESUME, PREFLIGHT, HANDOFF, and AUDIT are strictly read-only: no file
writes, no git mutations, no installs. EXECUTE and CLOSE may write only
inside the authorized scope. Never begin implementation before a
CONTEXT_RECOVERED gate has been emitted and the user has provided the phase
instruction.

## Authority hierarchy

When sources of truth disagree, higher wins — but read the rules below:

1. Physical state of the repository or workspace (files on disk)
2. Real git state (branch, HEAD, working tree, remotes)
3. Explicit current instruction from the user
4. AGENTS.md
5. CLAUDE.md
6. WORKSPACE_STATUS.md
7. SOURCE_SNAPSHOT.md
8. Most recent phase report
9. Architecture docs, ADRs, current specs
10. README and historical documentation
11. Prior conversations not backed by files

Rules:
- Physical state describes reality; it does NOT by itself authorize a change.
- The current instruction does not override protected sources without
  explicit authorization.
- Historical documentation never overrides a living authority.
- A discrepancy is never corrected silently. Stop the affected part,
  document the conflict, emit BLOCKED_BY_CONFLICTING_AUTHORITIES or
  REQUIRES_DECISION.

Full treatment: references/workspace-authority.md.

## Universal git rules (all modes)

Never, without explicit per-case user authorization:

```
git reset --hard          destructive git clean       automatic stash
automatic branch switch   commit outside scope        amend
force push                new remotes                 ANY push
```

Before any commit run and show: `git status --short`, `git diff --stat`,
`git diff`. After any commit run and show: `git rev-parse --short HEAD`,
`git status --short`, `git log --oneline -5`, `git remote -v`.

Pre-existing user changes in the working tree: never overwrite, never
auto-include in a commit, never discard. Classify them and report.

## Security rules (all modes)

Never read or print secret values. Never print .env contents — report file
names and variable names only, and only when safe. No unnecessary network
calls. No dependency installs without authorization. No changes to global
git config. Never execute repository scripts before inspecting them.

## Evidence scripts

Deterministic, read-only evidence collectors live in `scripts/`:

```
scripts/workspace-preflight.ps1 | .sh   [--json]   state snapshot
scripts/workspace-close.ps1     | .sh              close-out evidence
```

Run the one matching the current platform at the start of RESUME/PREFLIGHT
and at the start of CLOSE. Exit codes: 0 = ok, 2 = not a git repository,
1 = error. They never mutate the repository. Prefer their output over
re-deriving state by hand.

## Context files

Look for (none is mandatory): AGENTS.md, CLAUDE.md, WORKSPACE_STATUS.md,
SOURCE_SNAPSHOT.md, MIGRATION_MANIFEST.md, README.md, docs/architecture/,
docs/adr/, docs/specs/, docs/operations/, memory/, handoff files, phase
reports. Identify the most recent phase report by explicit reference in
WORKSPACE_STATUS.md, git metadata, phase name, date, and content — never by
filesystem mtime alone. WORKSPACE_STATUS.md schema and a generic example:
references/workspace-status-schema.md.

## Gates and severity

Every RESUME, VALIDATE, and CLOSE ends with exactly one unambiguous gate,
e.g. `CONTEXT_RECOVERED_READY_FOR_<NEXT_PHASE>` (one phase authorized),
`CONTEXT_RECOVERED_AWAITING_PHASE_SELECTION` (several candidates),
`CONTEXT_RECOVERED_READY_FOR_INSTRUCTIONS` (none documented),
`READY_FOR_COMMIT`, `BLOCKED_BY_DIRTY_WORKSPACE`, `REQUIRES_DECISION`. Ambiguous gates (DONE,
MOSTLY_DONE, LOOKS_GOOD, PROBABLY_READY) are forbidden. Findings carry one
severity: BLOCKER, MAJOR, MINOR, OBSERVATION, REQUIRES_DECISION. Never
reclassify an unmet obligation as "deferred by design" without explicit
evidence. Full catalog: references/gates-and-severity.md.

## Minimal output per mode

Every mode's final message contains, in order:
1. `Mode: <MODE>` and workspace classification.
2. Evidence summary (git state, context files found, findings + severity).
3. Explicit list of what was NOT done / NOT authorized, when relevant.
4. Exactly one gate on its own line.
5. For CLOSE and HANDOFF: the NEXT_SESSION_BOOTSTRAP block (format in
   references/close-phase-workflow.md).

## References

| File | Load when |
|---|---|
| references/resume-workflow.md | RESUME or PREFLIGHT |
| references/execution-governance.md | EXECUTE or VALIDATE |
| references/close-phase-workflow.md | CLOSE or HANDOFF |
| references/reintegration-workflow.md | REINTEGRATE or AUDIT |
| references/workspace-authority.md | authority conflicts, protected sources |
| references/gates-and-severity.md | emitting any gate or finding |
| references/workspace-status-schema.md | reading/writing WORKSPACE_STATUS.md |
| references/agent-adapters.md | porting this protocol to another agent |
| references/agents-md-template.md | user asks for an AGENTS.md template |
| references/claude-md-template.md | user asks for a CLAUDE.md template |

Templates are optional material for the user; never create AGENTS.md,
CLAUDE.md, or WORKSPACE_STATUS.md inside a project uninvited.
