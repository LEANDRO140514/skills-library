# Authority hierarchy and protected sources

## Hierarchy (higher wins)

1. Physical state of the repository/workspace (files on disk)
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

## Interpretation rules

- Physical/git state (1–2) establish FACTS. They never establish
  AUTHORIZATION. "The file already changed" does not license changing it more.
- The current instruction (3) can direct the work but cannot override
  protected sources or universal git rules without an explicit, per-case
  authorization ("yes, modify the monorepo file X for reason Y").
- Documented state (4–8) establishes expectations. When expectation and fact
  diverge, that is drift: report it, never silently reconcile it — neither by
  editing the doc to match git nor by mutating git to match the doc.
- Historical docs (10–11) inform; they never override a living authority.

## Conflicting authorities

When two authorities contradict (e.g. AGENTS.md forbids what the phase report
assumes, or WORKSPACE_STATUS.md declares a HEAD git does not show):
1. Stop the affected part of the work. Unaffected scope may continue.
2. Document the conflict: which authorities, what each says, evidence.
3. Emit BLOCKED_BY_CONFLICTING_AUTHORITIES (structural conflict) or
   REQUIRES_DECISION (needs a human choice between valid options).

## Protected sources

Four surfaces, distinguished at all times:

| Surface | Default access |
|---|---|
| Active workspace | READ-WRITE within scope |
| External original source | READ-ONLY |
| Institutional monorepo | READ-ONLY during isolated development |
| Reference repositories | READ-ONLY |

Identify protected paths from WORKSPACE_STATUS.md (Protected Source /
Protected Monorepo fields), SOURCE_SNAPSHOT.md, or the user. When a task
seems to require writing outside the workspace, stop and ask; a write outside
the workspace without a per-case authorization is BLOCKED_BY_SOURCE_INTEGRITY
or BLOCKED_BY_MONOREPO_INTEGRITY.
