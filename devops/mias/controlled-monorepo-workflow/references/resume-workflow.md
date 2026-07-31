# RESUME and PREFLIGHT workflows

Both modes are strictly read-only: no file writes, no git mutations, no
installs, no implementation.

## RESUME — step by step

1. Run the preflight script for the platform (`scripts/workspace-preflight.*`).
   Prefer `--json` for parsing; show the human output to the user.
2. Classify the workspace from the script output: monorepo, standalone-repo,
   git-worktree, external-copy-or-migration, or non-git-folder.
3. Read local authorities in hierarchy order if present: AGENTS.md, CLAUDE.md,
   WORKSPACE_STATUS.md, SOURCE_SNAPSHOT.md, most recent phase report. Do not
   require any of them to exist.
4. Identify the most recent phase report by: explicit reference inside
   WORKSPACE_STATUS.md → git metadata → phase name → date in content. Never by
   filesystem mtime alone.
5. Compare documented state vs physical state:
   - WORKSPACE_STATUS.md branch vs `git rev-parse --abbrev-ref HEAD`
   - WORKSPACE_STATUS.md HEAD vs `git rev-parse --short HEAD`
   - Declared working-tree state vs actual porcelain output
   - Declared remote vs `git remote -v`
6. Emit exactly one gate:
   - All consistent, context found → `CONTEXT_RECOVERED_READY_FOR_<NEXT_PHASE>`
     (take <NEXT_PHASE> from "Next Authorized Phase" in WORKSPACE_STATUS.md; if
     absent, use `CONTEXT_RECOVERED_READY_FOR_INSTRUCTIONS`).
   - HEAD mismatch → `BLOCKED_BY_WORKSPACE_HEAD_DRIFT`
   - Branch mismatch → `BLOCKED_BY_BRANCH_DRIFT`
   - Dirty tree not documented as expected → `BLOCKED_BY_DIRTY_WORKSPACE`
   - No context files and no way to infer state → `BLOCKED_BY_MISSING_CONTEXT`
   - Authorities contradict each other → `BLOCKED_BY_CONFLICTING_AUTHORITIES`
7. Report: classification, git state, context files found, discrepancies with
   severity, then the gate. Do NOT begin implementation. Wait for the user's
   phase instruction.

A dirty tree is not automatically a blocker: if WORKSPACE_STATUS.md or the
user documents expected in-progress changes, classify as OBSERVATION and note
which files. Undocumented changes → BLOCKED_BY_DIRTY_WORKSPACE and classify
the changes (user work in progress? leftover from crashed session? unknown?).

## PREFLIGHT — before starting an authorized phase

1. Confirm the authorized scope in writing (paths, packages, files allowed).
2. Identify protected sources: external original, protected monorepo,
   reference repositories. State explicitly that they are read-only.
3. From the preflight script: package manager, lockfiles, official scripts
   (read package.json "scripts" or equivalent — read, do not run).
4. Scan for obvious secrets/residue: .env files (names only), credentials in
   tracked files (report file names, never values), large binaries, build
   artifacts committed by mistake.
5. Output two explicit lists: ALLOWED ACTIONS and FORBIDDEN ACTIONS for this
   phase, derived from scope + authorities + universal rules.
6. Gate: `READY_FOR_<PHASE>` or a BLOCKED_BY_* gate.

## Fast resume (same session)

When RESUME already completed in the current session, do not repeat full
recovery. Run the preflight script again (preferably --json) and verify:
git root, branch, HEAD, working tree, cached remote reference, untracked
files with individual paths, and the sha256 hashes of previously loaded
authority files (all provided by the script output).

- All authority hashes unchanged → reuse the prior interpretation of those
  authorities without rereading them.
- Any authority hash changed → reread ONLY the changed authority and
  reevaluate contradictions against the others.
- Never assume authorities or untracked directory contents are unchanged
  merely because short git status looks the same — compare the hashes and
  the untracked path list.
- Compare evidence fingerprints: identical fingerprint = the rechecked field
  set is unchanged. Different fingerprint = diff the fields to locate what
  moved before proceeding.

## Remote-state language

The preflight script never fetches, so remote freshness is never verified by
it. Report cached remote state with exactly these labels:

- CACHED_REMOTE_REF_MATCH — local HEAD matches the locally cached
  remote-tracking reference.
- CACHED_REMOTE_REF_DIVERGED — ahead/behind vs the cached reference.
- REMOTE_FRESHNESS_NOT_VERIFIED — always, unless a fetch actually ran.

Never state that a branch "is synchronized with" the remote service unless
remote freshness was actually verified by a successful network fetch (which
itself requires authorization). Preferred wording: "Local HEAD matches the
locally cached remote-tracking reference. Remote freshness was not verified."

## Untracked-content verification

Use `git status --short --untracked-files=all` (the script already does).
When a documented, expected untracked entry is a directory, compare at
least: relative file paths, file count, and file sizes; use hashes when
practical and safe. Never print file contents or secret values. Classify:

- EXPECTED_UNTRACKED_UNCHANGED — matches the documented expectation.
- EXPECTED_UNTRACKED_CONTENT_DRIFT — documented entry exists but its
  contents changed (paths/count/sizes/hashes differ).
- UNEXPECTED_UNTRACKED — present but not documented anywhere.
- POTENTIAL_SECRET — name/pattern suggests credentials; report name only.

## Evidence fingerprints

Prefer the script's JSON output. The script computes a sha256
evidence_fingerprint over a canonical field set (git root, branch, HEAD,
working tree, cached remote state, authority hashes, context files,
untracked count) excluding the timestamp. Use "byte-identical" ONLY when an
actual byte-level or canonical-hash comparison was performed; otherwise say
"No differences were detected in the fields rechecked."

## Two-dimensional classification

Report structure and role separately; never collapse them:

- Repository structure (physical facts, script-detected): standalone-repo |
  formal-monorepo | worktree | non-git-folder.
- Repository role (authority-assigned): institutional-source-of-truth |
  external-development-workspace | ordinary-repository | reference-source.

Role comes from WORKSPACE_STATUS.md, AGENTS.md, or the user — never inferred
solely from folder structure. A repo with monorepo tooling is not
automatically the institutional source of truth. Undetermined role stays
"undetermined" until an authority assigns it.
