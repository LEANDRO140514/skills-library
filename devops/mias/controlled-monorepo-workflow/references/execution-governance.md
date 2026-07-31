# EXECUTE and VALIDATE governance

## EXECUTE

- Work only inside the authorized scope. Scope is what the user authorized
  in the current phase instruction plus what authorities permit — nothing more.
- Never expand scope for convenience ("while I'm here..."). Finding a bug or
  improvement outside scope → record it as REQUIRES_DECISION, do not fix it.
- Avoid collateral changes: no reformatting untouched files, no dependency
  bumps, no config "cleanups" unless they ARE the scope.
- Pre-existing user changes: never overwrite, never auto-include, never
  discard. Classify and report.
- No push under any circumstance without express authorization.
- Keep a running list of files touched; it feeds VALIDATE and CLOSE.

## VALIDATE

Use the project's real scripts — never invent parallel commands when official
ones exist. Discover them in package.json "scripts", Makefile, justfile,
composer.json, pyproject, etc. Read them before running them.

Order of checks (run those that exist, skip and report those that do not):
1. Reproducible install when dependencies changed: `npm ci` / `pnpm install
   --frozen-lockfile` / `yarn install --immutable` or ecosystem equivalent.
   Requires authorization if it was not part of the phase.
2. Type check (tsc or equivalent).
3. Lint — WITHOUT autofix. `--fix` requires explicit authorization.
4. Tests.
5. Build.
6. Lockfile integrity: lockfile changed? Was that authorized? Unauthorized
   lockfile drift → `BLOCKED_BY_LOCKFILE_DRIFT`.
7. Git diff review: `git status --short`, `git diff --stat`, `git diff`.
   Every changed file must map to the scope. Out-of-scope changes →
   `BLOCKED_BY_SCOPE_VIOLATION`.
8. Project-specific checks when defined by authorities: routes, assets,
   contracts, schema migrations.

Failures map to gates: dependency → BLOCKED_BY_DEPENDENCY_FAILURE, build →
BLOCKED_BY_BUILD_FAILURE, tests → BLOCKED_BY_TEST_FAILURE. Secrets appearing
in the diff → BLOCKED_BY_SECRET_EXPOSURE (report file names only). Changes
that would touch a protected source → BLOCKED_BY_SOURCE_INTEGRITY or
BLOCKED_BY_MONOREPO_INTEGRITY.

All green and in scope → `READY_FOR_COMMIT`. Commit itself belongs to CLOSE
and still requires the phase to authorize it.
