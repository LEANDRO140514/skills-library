# REINTEGRATE and AUDIT workflows

## REINTEGRATE — selective integration into the monorepo

Never copy whole folders into a monorepo without audit. Reintegration is
element by element (file, module, package, config), each classified as:

| Class | Meaning |
|---|---|
| KEEP | Integrates now, as-is, into the target location |
| MOVE_LATER | Valid but its target location is not ready |
| SHARE_LATER | Should become a shared package before moving |
| REFACTOR_BEFORE_MOVE | Needs changes to meet monorepo standards first |
| LEGACY_KEEP | Stays in the workspace as legacy, not integrated |
| REQUIRES_DECISION | Needs human authority to classify |
| DISCARD | Not integrated, can be deleted after confirmation |

Process:
1. AUDIT first (below) on both workspace and target monorepo. The monorepo
   remains read-only during planning.
2. Build the classified inventory (table: element, class, target path,
   reason, risks).
3. Detect collisions: same-name files/modules in the target, conflicting
   dependencies, lockfile impact, duplicated shared code.
4. Produce an integration plan: ordered steps, each with its own scope,
   validation, and gate. Copying happens only in a later EXECUTE phase that
   the user explicitly authorizes, never during planning.
5. Gate: `READY_FOR_REINTEGRATION_PLANNING` when the plan is delivered, or
   REQUIRES_DECISION / BLOCKED_BY_* when classification is incomplete.

## AUDIT

Read-only investigation. Deliver evidence before proposing any change.
- Never modifies files, git state, or configs.
- Output: findings with severity, evidence per finding (command + relevant
  output), and open questions. Proposals go in a separate section clearly
  marked as NOT EXECUTED.
- If the user then wants changes, that is a new EXECUTE phase with its own
  scope and authorization.
