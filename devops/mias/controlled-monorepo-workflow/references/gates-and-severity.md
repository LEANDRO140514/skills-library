# Gates and severity catalog

Exactly one gate per RESUME, VALIDATE, and CLOSE, on its own line, verbatim.
Placeholders in <> are filled with the real phase or reason in UPPER_SNAKE.

## Recovery gates

CONTEXT_RECOVERED_READY_FOR_<NEXT_PHASE>   (one next phase explicitly authorized)
CONTEXT_RECOVERED_AWAITING_PHASE_SELECTION (multiple candidate phases; human must choose)
CONTEXT_RECOVERED_READY_FOR_INSTRUCTIONS   (no next phase documented)
BLOCKED_BY_WORKSPACE_HEAD_DRIFT
BLOCKED_BY_BRANCH_DRIFT
BLOCKED_BY_DIRTY_WORKSPACE
BLOCKED_BY_MISSING_CONTEXT
BLOCKED_BY_CONFLICTING_AUTHORITIES
BLOCKED_BY_INSUFFICIENT_EVIDENCE

## Execution and validation gates

READY_FOR_VALIDATION
READY_FOR_COMMIT
BLOCKED_BY_SCOPE_VIOLATION
BLOCKED_BY_DEPENDENCY_FAILURE
BLOCKED_BY_BUILD_FAILURE
BLOCKED_BY_TEST_FAILURE
BLOCKED_BY_LOCKFILE_DRIFT
BLOCKED_BY_SECRET_EXPOSURE
BLOCKED_BY_SOURCE_INTEGRITY
BLOCKED_BY_MONOREPO_INTEGRITY

## Close gates

READY_FOR_<NEXT_PHASE>
READY_FOR_REINTEGRATION_PLANNING
REQUIRES_DECISION
BLOCKED_BY_<REASON>

## Forbidden gates

DONE, MOSTLY_DONE, LOOKS_GOOD, PROBABLY_READY, or any phrasing that leaves
the state ambiguous. If no listed gate fits, use BLOCKED_BY_<REASON> with a
precise reason.

## Severity

| Level | Rule |
|---|---|
| BLOCKER | Prevents advancing. The gate must be a BLOCKED_BY_*. |
| MAJOR | Requires fix or explicit user acceptance before the next phase. |
| MINOR | Does not prevent advancing; must be documented in the close report. |
| OBSERVATION | Informational; no immediate action required. |
| REQUIRES_DECISION | Needs human authority; never resolve it unilaterally. |

Never downgrade severity to make a gate pass. Never reclassify an unmet
obligation as "deferred by design" without explicit written evidence that the
user deferred it.

## Evidence status labels (not gates)

Attach to findings inside the report; the gate stays singular.

Remote state: CACHED_REMOTE_REF_MATCH, CACHED_REMOTE_REF_DIVERGED,
REMOTE_FRESHNESS_NOT_VERIFIED.

Untracked content: EXPECTED_UNTRACKED_UNCHANGED,
EXPECTED_UNTRACKED_CONTENT_DRIFT, UNEXPECTED_UNTRACKED, POTENTIAL_SECRET.

POTENTIAL_SECRET findings are at least MAJOR; if the file is staged or
tracked, the gate is BLOCKED_BY_SECRET_EXPOSURE.
