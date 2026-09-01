# Skills Philosophy

Canonical doctrine for the Algorithmus Skills Library.

This document defines **why** the library exists and **how capability decisions are
governed**. It is normative and durable. It does not depend on any particular model,
harness, agent, or product. Where this document and other documentation disagree about
intent, this document wins; where it and the real state of the repository or an explicit
user instruction disagree about facts, those win.

---

## 1. What the library is — and is not

The Algorithmus Skills Library is **the curated arsenal of capabilities Algorithmus needs
to do its real work.**

It is **not**:

- a collection of interesting Skills;
- a personal marketplace;
- a list of whatever is new on GitHub;
- a hype-driven repository;
- an obligation to continuously search for new capabilities;
- a system where the arsenal dictates the work.

It **is** a governed registry: every capability in it has been curated because it
demonstrably improves how Algorithmus works, and every capability enters through the same
gates.

---

## 2. Central principle

> **Work determines which Skills we need. The library does not determine which work we do.**

The correct flow is always:

```
REAL WORK
  → a need arises
  → is the capability already active?
      → if not: does it exist in our skills-library?
          → if not: we go out into the world to find it
              → we prefer a proven solution over inventing our own
              → only if no adequate solution exists: we build it
  → validate
  → curate
  → promote
  → the library learns
```

External search is **not** a permanent activity. It is a **release valve**. Its purpose is
to stop Algorithmus from becoming locked inside its own way of working. We do not chase
novelty because it exists; we look outward when a real work need is not covered by our
arsenal.

---

## 3. Resolution order

When a task needs a capability, resolve in this order. Stop at the first step that
genuinely satisfies the need.

1. **Capability already active.** If sufficient capability already exists in the
   runtime/context, use it.
2. **Skills-library.** Search our governed source of truth first (`_INDEX.csv` via
   `ruta_biblioteca`, including `_archivo` / `razon_archivo` handling).
3. **External ecosystem.** Only when a real need exists that the library does not cover,
   and only when governance permits the search.
4. **Evaluate before adopting.** New, popular, or highly-starred does not mean it enters
   (see §4).
5. **Build only when no adequate solution exists.** Do not reinvent what someone else has
   already solved well.
6. **Validate / scan / govern.** A Skill found outside is a **candidate**, not a trusted
   Algorithmus capability. It passes the Skill Gate (security scan) and index review like
   anything else.
7. **Promote ≠ deploy.** Promotion into the canonical source and deployment into a runtime
   remain separate decisions, each with its own explicit approval.

A stage blocked by governance is **not** the same as `NOT_FOUND`. Only a genuine
`NOT_FOUND`, after every required discovery stage has actually run, can lead to building a
new Skill.

---

## 4. Anti-hype principle

> **Novelty ≠ value.**

We do **not** incorporate a Skill because it shipped this week, a well-known person
published it, it has many stars, it appears on a leaderboard, it is fashionable, or another
agent calls it "must have."

A Skill earns entry only if it demonstrably improves our work. Minimum questions:

- Does it solve a problem we actually have?
- Is it better than our current capability?
- Does it reduce time?
- Does it reduce errors?
- Does it improve consistency?
- Is it reusable?
- Is its cognitive/operational cost justified?
- Does it fit how we work?
- Can we govern and maintain it?

If the answer is no: **it does not enter.**

---

## 5. Pekín and the Samurai

**Pekín** is a metaphor for the house: our experience, our patterns, our operational
memory, our doctrine, the solutions we know work. Pekín preserves experience.

An organization that only listens to itself risks becoming complacent. For that reason a
deliberately external figure exists: the **Super Samurai**.

The Samurai does not exist to please Pekín and does not belong intellectually to the house.
Its function is to **contradict when necessary**. It periodically observes how we work,
which Skills we use, which Skills are aging, which external capabilities have improved,
which of our own procedures have become needlessly complex, and where the outside world has
already solved something better than we still do it.

The Samurai's job is **not** to bring novelty for its own sake. A successful Samurai review
may legitimately conclude:

> **NO CHANGE** — the current arsenal remains adequate.

The Samurai is not required to create or improve a Skill on every run. Every Samurai
recommendation must demonstrate value before it modifies the arsenal.

> Pekín preserves experience. The Samurai fights complacency. Neither is automatically
> right.

---

## 6. delivery-first-cto boundary

`delivery-first-cto` is **project governance**, not Skill lifecycle management. Its central
question is *"Should we build this?"* — covering commercial outcome, Build/Buy/Configure/
Integrate, time-to-value, vertical slice, avoiding over-construction, CLIENT DELIVERY vs
PLATFORM vs R&D, stop-loss, and revisiting whether a past technical decision still holds.

It may naturally raise a capability need when a project surfaces one. It **must not** become
a skill-router, a find-skills, a catalog, a scanner, a promoter, or a Skill lifecycle
manager. Separation of responsibilities is preserved.

---

## 7. Conceptual roles

| Role | Responsibility |
|---|---|
| **skill-router** | Resolution control plane: *"which capability should handle this need?"* |
| **find-skills** | Discovery: local/library first, then external only when warranted. |
| **skill-creator** | Creation of genuinely non-existent capabilities. Not the first resort. |
| **skill-scanner** | Security/quality inspection under existing governance. |
| **skill-promote** | Governs entry into the canonical source. |
| **skills-library** | Source of truth of the Algorithmus arsenal. |
| **super-samurai-evolution** | External critic/evolver of the arsenal; may return NO CHANGE. |
| **controlled-monorepo-workflow** | Development governance: isolation, PREFLIGHT/EXECUTE/VALIDATE/CLOSE, git mutation control, promotion, deployment boundaries. |
| **delivery-first-cto** | Project governance and Build/Buy/Configure/Integrate decisions. |

Each role owns one responsibility instead of duplicating the others.

---

## 8. Governing multi-agent systems

The first important consumer of this doctrine is a coordinated multi-agent software
factory, where different agents hold different roles (lead, builders, reviewer, tester,
security, substitute). The doctrine that governs them is:

> **Agents do not arrive at a project with their own ideological arsenal. They work under
> capabilities governed by Algorithmus.**

Conceptual model:

```
ORCHESTRATOR
  → agent needs a capability
  → skill-router
  → Algorithmus Skills Library
  → approved capability

  (library miss)
  → external search
  → candidate
  → review / scan / approval
  → promote
  → deploy when appropriate
```

No coordinated agent has implicit authority to:

- install Skills arbitrarily from GitHub;
- add whole packs "because they are good";
- change the canonical arsenal;
- promote a Skill;
- deploy a Skill globally;
- skip the library and search outside for convenience.

This doctrine is independent of any specific orchestration product. The library must
survive even if a given orchestrator is no longer used.

---

## 9. The principle, restated

> Work determines which Skills we need.
> The library does not determine which work we do.
> We use what works.
> We look outside when we need to.
> We build when no one has solved it adequately.
> We keep only what improves our work.
> Pekín preserves experience.
> The Samurai fights complacency.
