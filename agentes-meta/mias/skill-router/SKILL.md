---
name: skill-router
description: Decide which capability should handle a task and route it through the governed resolution chain — check what's already active in context, then delegate discovery to find-skills, creation to skill-creator, and isolation/validation/promotion to controlled-monorepo-workflow. Trigger this whenever a task needs a capability that isn't already obviously active, before searching, installing, activating, or creating anything directly.
---

# Skill Router

## 1. Purpose

Skill Router answers one question: "what should handle this task?" It is a control plane — it decides where a capability need goes next and enforces the approval gates along the way. It does not implement discovery, authoring, evaluation, installation, or version-control mechanics itself. Those live in find-skills, skill-creator, and controlled-monorepo-workflow. This skill should be understandable without knowing any prior version of it existed.

## 2. Authority

The active project's CLAUDE.md, AGENTS.md, and harness/permission configuration are the highest operational authority and always override this router's default behavior. If governance forbids an action — network access, writes, git mutations, anything — the router stops and reports the block. It does not work around it.

Skill Router never has authority of its own to:

- create, install, activate, promote, or deploy a skill;
- mutate the canonical skills-library, or write outside its own reported scope;
- modify global `~/.claude` state, global CLAUDE.md, global settings, or global hooks;
- modify another project, repository, or worktree — including its configuration or capability deployment — without that project's own explicit authorization and in accordance with that project's own governance;
- maintain operator state, project registries, or daily summaries;
- create, switch, or remove branches/worktrees, or stage/commit/push;
- use network or external tools when governance prohibits it.

Each of these requires an explicit authorized actor — the user, or a governance-approved phase in controlled-monorepo-workflow. The router requests these actions; it never performs them silently.

## 3. Skill Resolution Protocol

Resolve in this order. Stop at the first step that satisfies the need.

**Step 1 — Context check (cheap, router-owned).**
Is a capability that clearly satisfies this task already active in the current runtime/context? If yes, use it and report `RESOLVED_IN_CONTEXT`. This is recognizing something already in front of you — not a filesystem scan, not a catalog lookup. If answering it requires scanning `~/.claude/skills`, parsing `_INDEX.csv`, or reconstructing a path, that is not this step — that is Step 2.

**Step 2 — Delegate discovery to find-skills.**
Hand the need to find-skills. It owns, in order: already-active-globally check, `C:\skills-library\_INDEX.csv` lookup via `ruta_biblioteca` (including `_archivo`/`razon_archivo` handling), then external ecosystem search. Do not duplicate any part of that logic — consume its outcome:

- **Active match** → present it; activate only if the activation step itself is something governance already permits for this task. Report `FOUND_ACTIVE` or `FOUND_LIBRARY`.
- **Archived match** → never treat as a normal result. Surface the `razon_archivo` reason and require explicit confirmation before proceeding. Report `ARCHIVED_NEEDS_CONFIRMATION`.
- **External candidate presented** → present it and require explicit approval before activation. Report `EXTERNAL_CANDIDATE_NEEDS_REVIEW` while approval is pending.
- **External discovery blocked by governance** → local checks found no adequate match and external discovery would normally run next, but governance prohibits network/external calls. Do not let find-skills reach out. A blocked stage is not a miss — do not report `NOT_FOUND` and do not proceed to Step 3 on this basis. Report `BLOCKED_BY_GOVERNANCE`, stop, and surface the authorization/decision needed to unblock it.
- **Genuine `NOT_FOUND`** → report `NOT_FOUND` only once every discovery stage required for this path — local, and external whenever external is authorized — has actually run and found nothing. Proceed to Step 3 only from this outcome.

**Step 3 — Delegate creation to skill-creator.**
Only after find-skills has genuinely returned `NOT_FOUND` (not a stage blocked by governance — see above), and only with the user's go-ahead, hand the requirement to skill-creator. It owns requirements elicitation, SKILL.md authoring, resource/script/asset design, eval design, evaluation, grading, benchmarking, iteration, and packaging. Report `CREATION_ROUTED` on handoff. Do not author skill content yourself.

**Step 4 — Delegate isolation, validation, and promotion to controlled-monorepo-workflow.**
A candidate from skill-creator is not usable capability yet. Route it through controlled-monorepo-workflow: isolated staging/worktree, its PREFLIGHT/EXECUTE/VALIDATE/CLOSE lifecycle, validation/evals/review. Report `CANDIDATE_REQUIRES_VALIDATION`. Promotion into the skills-library and any deployment after that each require their own explicit human approval — report `REQUIRES_APPROVAL`, then `READY_FOR_PROMOTION`, then `PROMOTED_REQUIRES_DEPLOYMENT_AUTH` as each gate clears. The router never performs the git/worktree mechanics, the promotion write, or the deployment itself.

There is no automatic path from `NOT_FOUND` to a deployed skill. Every step from Step 3 onward has a human approval gate before the next one runs.

## 4. Delegation boundaries

**find-skills owns:** installed-capability discovery (global and project-local), `_INDEX.csv` lookup, `nombre`/`categoria` matching, `ruta_biblioteca` resolution, `_archivo`/`razon_archivo` handling, local activation/copy mechanics, external ecosystem search, and external-candidate quality checks. Refer to it for all of this; never reimplement it here.

**skill-creator owns:** requirements elicitation, SKILL.md authoring methodology, supporting-resource design, eval creation, with-skill/baseline evaluation, grading, benchmarking, iteration, and packaging. Refer to it for all skill authoring and evaluation.

**controlled-monorepo-workflow owns:** isolated worktree/staging creation, read-only vs. writable authority, the PREFLIGHT/EXECUTE/VALIDATE/CLOSE lifecycle, validation, promotion into the skills-library, all git mutations, reintegration, and deployment-authorization boundaries. Refer to it for all isolation, validation, and promotion mechanics — do not touch git or the filesystem for these purposes here.

## 5. Approval gates (non-negotiable)

Stop and require explicit human approval before:

- activating an archived capability;
- activating an external candidate;
- letting a `NOT_FOUND` result become license to create (i.e., before Step 3 begins);
- promoting a validated candidate into the skills-library;
- any deployment following promotion;
- any write, git mutation, or external/network call that active project governance does not already clearly authorize.

Governance always wins over a request. If authorization is ambiguous, stop and ask rather than proceeding on a best guess.

## 6. Failure / blocked behavior

When a step cannot proceed — missing authorization, governance forbids network/external access, an approval gate is pending — stop cleanly and report three things: what was being attempted, which gate or authority is blocking it, and what decision would unblock it. Use `BLOCKED_BY_GOVERNANCE` for anything project governance forbids outright. Never route around a blocked step by taking a shortcut the router itself happens to be able to perform.

## 7. Reporting

Resolution outcomes are reporting labels only — not a persistent state machine, not a file, not global state:

`RESOLVED_IN_CONTEXT` · `FOUND_ACTIVE` · `FOUND_LIBRARY` · `ARCHIVED_NEEDS_CONFIRMATION` · `EXTERNAL_CANDIDATE_NEEDS_REVIEW` · `NOT_FOUND` · `CREATION_ROUTED` · `CANDIDATE_REQUIRES_VALIDATION` · `REQUIRES_APPROVAL` · `READY_FOR_PROMOTION` · `PROMOTED_REQUIRES_DEPLOYMENT_AUTH` · `BLOCKED_BY_GOVERNANCE`

Every response ends by stating the current outcome and which party — user, find-skills, skill-creator, or controlled-monorepo-workflow — owns the next step.

## 8. Examples

- *"Is there a way to check my code for security issues?"* — Step 1 finds nothing already active. Step 2 delegates to find-skills, which returns an active global match → `FOUND_ACTIVE`; report it and how to invoke it.
- *"I need something that formats these XBRL filings and nothing like that seems to exist."* — Step 2 returns `NOT_FOUND` from find-skills. Ask the user before proceeding. On yes, `CREATION_ROUTED` to skill-creator; the resulting candidate goes to controlled-monorepo-workflow for staging and validation before promotion is even discussed.
- *"Just grab that skill from GitHub and turn it on."* — find-skills identifies it as an external candidate. Do not activate it directly: present it and require explicit approval. If network access is currently disallowed by governance, report `BLOCKED_BY_GOVERNANCE` instead of letting find-skills reach out.
