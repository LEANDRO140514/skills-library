---
name: find-skills
description: Helps users discover and install agent skills when they ask questions like "how do I do X", "find a skill for X", "is there a skill that can...", provide a GitHub URL to install directly, or express interest in extending capabilities. This skill should be used when the user is looking for functionality that might exist as an installable skill.
metadata:
  version: '1.2.0'
---

# Find Skills

This skill helps you discover and install skills from the open agent skills ecosystem.

## Governed resolution (inside the skills-library repo)

When you are working in the governed `skills-library` repo, `_INDEX.csv` is the
registry and **`find-skills` resolves against it — it is not a grep of names.**

**Call the script. Do not eyeball the CSV and do not reconstruct paths.**

```bash
./scripts/find-skills.sh <name>
./scripts/find-skills.sh --query "<substring>"
```

It emits one JSON object per matching row
(`nombre`, `ruta_biblioteca`, `mias_o_comunidad`, `scan_verdict`, `scan_waiver`,
`confianza`, `status`) and never writes `_INDEX.csv`. It does not run SkillSpector.

| status | meaning | what the caller does |
|---|---|---|
| `allow` | `mias` (not `deny`, not archived), or `comunidad` + `scan_verdict=allow` | resolve via `ruta_biblioteca`, copy (never move) to the target |
| `review` | `comunidad` (or `mias`) + `scan_verdict=review` **with** a non-empty `scan_waiver` | resolvable, but mark `needs_review=true` — surface the waiver; never load it silently as if it were `allow` |
| `blocked` | `_archivo/` path, `scan_verdict=deny`, `scan_verdict=review` with no waiver, or **`comunidad` with empty/absent `scan_verdict`** | do **not** resolve. Emit `BLOCKED_BY_GOVERNANCE`, not `NOT_FOUND`. A comunidad skill with no scan is "comunidad ciega" — it is blocked until the Skill Gate scores it. |
| `unindexed` | folder exists on disk but has no `_INDEX.csv` row | do not resolve, do not invent a row — report it and let promotion add the row |
| `not_found` | no name match anywhere | genuine miss — this is the only status that may lead to `skill-creator` |

Exit code: `0` if at least one result is `allow` or `review`; `2` if every
result is `blocked` / `unindexed` / `not_found`.

**`blocked` is never `NOT_FOUND`.** Only `not_found` authorizes creating a new skill.

Outside the governed repo (no `_INDEX.csv` in reach), fall back to the local /
ecosystem flow below.

## When to Use This Skill

Use this skill when the user:

- Asks "how do I do X" where X might be a common task with an existing skill
- Says "find a skill for X" or "is there a skill for X"
- Asks "can you do X" where X is a specialized capability
- Expresses interest in extending agent capabilities
- Wants to search for tools, templates, or workflows
- Mentions they wish they had help with a specific domain (design, testing, deployment, etc.)
- Provides a GitHub URL or `owner/repo` and asks to install it directly

## What is the Skills CLI?

The Skills CLI (`npx skills`) is the package manager for the open agent skills ecosystem. Skills are modular packages that extend agent capabilities with specialized knowledge, workflows, and tools.

**Key commands:**

- `npx skills find [query]` - Search for skills interactively or by keyword
- `npx skills add <package>` - Install a skill from GitHub or other sources
- `npx skills check` - Check for skill updates
- `npx skills update` - Update all installed skills

**Browse skills at:** https://skills.sh/

## Installing from a GitHub URL

When a user provides a GitHub link directly, you can skip the search flow and install immediately. The CLI accepts both full URLs and `owner/repo` shorthand.

### List available skills first (optional)

```bash
npx skills add https://github.com/anthropics/skills -l
```

### Install all skills from the repo

```bash
npx skills add https://github.com/anthropics/skills --all
```

### Install a specific skill from the repo

```bash
# -s <name>: select a specific skill, -g: install globally, -y: skip confirmation
npx skills add https://github.com/anthropics/skills -s design-skills -g -y
```

### Shorthand format works too

```bash
npx skills add anthropics/skills --all
```

> **Tip:** Use `-l` (list) first so the user can see what's available before committing to install.

## How to Help Users Find Skills

### Step 0: Check What You Already Have First

Before searching the open ecosystem, check what's already available locally — in this order.
Only fall through to Step 1 (external search) if neither check below finds anything.

**0a. Is it already active globally?**

Check `C:\Users\vonde\.claude\skills\` for a folder matching the need (by name or obvious
description match). If it's already there, **do not copy anything from the library** — tell the
user it's already active globally and how to invoke it. This avoids duplicate copies of the same
skill living in two places at once.

**0b. Is it in the local library, just not active anywhere yet?**

If it's not in global and you are inside the `skills-library` repo, run the governed
resolver — **do not read `_INDEX.csv` by hand**:

```bash
./scripts/find-skills.sh <name>
```

Act on the `status` field per the table in *Governed resolution* above:
`allow`/`review` → resolve via the returned `ruta_biblioteca` (copy, never move);
`blocked` → `BLOCKED_BY_GOVERNANCE`, stop; `unindexed` → report, do not invent a row;
`not_found` → continue to Step 1. The `ruta_biblioteca` in the output is authoritative —
never reconstruct a path from `categoria`/`mias_o_comunidad`/`nombre`.

**If the match's `ruta_biblioteca` points inside `_archivo/` (status `blocked`), treat it
differently from a normal miss** — it was deliberately set aside, not just uncategorized:

1. Check the `razon_archivo` column — it says why: `duplicado` (already available another way,
   e.g. a factory-installed pack), `descartado` (a superseded/inferior version), or `pospuesto`
   (set aside pending a decision, not reviewed yet).
2. Do **not** offer it as a normal result. Instead, surface it explicitly as archived and show the
   reason, e.g.: *"Encontré `wayfinder` pero está archivada (duplicado: ya viene de fábrica en
   Hermes, sin valor adicional). ¿Seguro que quieres activarla igual?"*
3. Only copy it if the user explicitly confirms after seeing the reason — this is an extra
   confirmation step on top of the normal one, not a replacement for it.

**If the match is in an active category** (not `_archivo`), it's a normal offer:
1. Show the user the row: `nombre`, `categoria`, `confianza` (alta/media/baja — call out anything
   `baja` explicitly, it means the categorization or origin was uncertain when indexed).
2. Ask where to activate it: this project's `.claude\skills\` (if working inside a repo) or global
   `.claude\skills\` (only if it's clearly transversal — ask, don't assume which).
3. Copy (never move) the folder at `ruta_biblioteca` to the chosen destination. The library itself
   is a reference source and is never modified or consumed by this process.
4. Verify the copy landed completely (`SKILL.md` plus any subfolders) before telling the user it's
   ready to use.

If there's no match in the library either, continue to Step 1 below — the external search flow is
unchanged.

### Step 1: Understand What They Need

When a user asks for help with something, identify:

1. The domain (e.g., React, testing, design, deployment)
2. The specific task (e.g., writing tests, creating animations, reviewing PRs)
3. Whether this is a common enough task that a skill likely exists

### Step 2: Check the Leaderboard First

Before running a CLI search, check the [skills.sh leaderboard](https://skills.sh/) to see if a well-known skill already exists for the domain. The leaderboard ranks skills by total installs, surfacing the most popular and battle-tested options.

For example, top skills for web development include:
- `vercel-labs/agent-skills` — React, Next.js, web design (100K+ installs each)
- `anthropics/skills` — Frontend design, document processing (100K+ installs)

### Step 3: Search for Skills

If the leaderboard doesn't cover the user's need, run the find command:

```bash
npx skills find [query]
```

For example:

- User asks "how do I make my React app faster?" → `npx skills find react performance`
- User asks "can you help me with PR reviews?" → `npx skills find pr review`
- User asks "I need to create a changelog" → `npx skills find changelog`

### Step 4: Verify Quality Before Recommending

**Do not recommend a skill based solely on search results.** Always verify:

1. **Install count** — Prefer skills with 1K+ installs. Be cautious with anything under 100.
2. **Source reputation** — Official sources (`vercel-labs`, `anthropics`, `microsoft`) are more trustworthy than unknown authors.
3. **GitHub stars** — Check the source repository. A skill from a repo with <100 stars should be treated with skepticism.

### Step 5: Present Options to the User

When you find relevant skills, present them to the user with:

1. The skill name and what it does
2. The install count and source
3. The install command they can run
4. A link to learn more at skills.sh

Example response:

```
I found a skill that might help! The "react-best-practices" skill provides
React and Next.js performance optimization guidelines from Vercel Engineering.
(185K installs)

To install it:
npx skills add vercel-labs/agent-skills@react-best-practices

Learn more: https://skills.sh/vercel-labs/agent-skills/react-best-practices
```

### Step 6: Offer to Install

If the user wants to proceed, you can install the skill for them:

```bash
npx skills add <owner/repo@skill> -g -y
```

The `-g` flag installs globally (user-level) and `-y` skips confirmation prompts.

## Common Skill Categories

When searching, consider these common categories:

| Category        | Example Queries                          |
| --------------- | ---------------------------------------- |
| Web Development | react, nextjs, typescript, css, tailwind |
| Testing         | testing, jest, playwright, e2e           |
| DevOps          | deploy, docker, kubernetes, ci-cd        |
| Documentation   | docs, readme, changelog, api-docs        |
| Code Quality    | review, lint, refactor, best-practices   |
| Design          | ui, ux, design-system, accessibility     |
| Productivity    | workflow, automation, git                |

## Tips for Effective Searches

1. **Use specific keywords**: "react testing" is better than just "testing"
2. **Try alternative terms**: If "deploy" doesn't work, try "deployment" or "ci-cd"
3. **Check popular sources**: Many skills come from `vercel-labs/agent-skills` or `ComposioHQ/awesome-claude-skills`

## When No Skills Are Found

If no relevant skills exist:

1. Acknowledge that no existing skill was found
2. Offer to help with the task directly using your general capabilities
3. Suggest the user could create their own skill with `npx skills init`

Example:

```
I searched for skills related to "xyz" but didn't find any matches.
I can still help you with this task directly! Would you like me to proceed?

If this is something you do often, you could create your own skill:
npx skills init my-xyz-skill
```
