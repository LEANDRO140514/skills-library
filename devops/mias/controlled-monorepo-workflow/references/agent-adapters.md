# Porting this protocol to other agents

The skill core is agent-agnostic: modes, authority hierarchy, gates,
severity, git rules, and the scripts are plain protocol + bash/PowerShell.
Only the packaging differs per agent. Do not fork the content — adapt the
loading mechanism and point back to this skill as the canonical source.

## Claude Code (implemented)
- Global skill: ~/.claude/skills/controlled-monorepo-workflow/
- Wrappers: ~/.claude/commands/resume-workspace.md and close-phase.md
  (thin: select mode, defer to the skill).
- Optional SessionStart hook: light preflight only; fail-safe.

## Cursor (conceptual — do not implement yet)
- Global user rule: paste a condensed version of SKILL.md (modes + hierarchy
  + git rules + gates) into Cursor Settings → Rules for AI, plus the path to
  the canonical skill folder so the agent can read references on demand.
- Project rule: .cursor/rules/controlled-monorepo-workflow.mdc with
  `alwaysApply: false` and a description mirroring the skill description.
- Command wrapper: no native slash commands; instruct via the rule that
  "resume workspace" / "close phase" phrases select the mode.
- AGENTS.md interoperability: Cursor reads AGENTS.md natively in recent
  versions; keep repo-level authority there, not in Cursor-only files.

## DeepClaude
- Verify, do not assume: check whether it reuses ~/.claude and whether it
  loads Claude Code skills and hooks. Test with a dummy skill before relying
  on it. If it shares the install, nothing extra is needed; if not, treat it
  like "other agents" below.

## Goose / Forge / other agents
- Provide the protocol as a system-prompt extension or instruction file the
  agent loads at session start, containing: mode table, hierarchy, git rules,
  gate list, and the two script paths. Scripts run as-is (bash or pwsh).
- The NEXT_SESSION_BOOTSTRAP block and WORKSPACE_STATUS.md are plain files:
  every agent can read them, which is what makes cross-agent handoff work.

## Rule for all adapters
An adapter may condense, never contradict. If an adapter needs a behavior the
core forbids (e.g. auto-push), the answer is no — fix the workflow, not the
protocol.
