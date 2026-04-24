---
name: docs-as-code
description: Repository-as-system-of-record protocol. Invoke when starting a feature/sprint with ≥3 tasks, making an architectural decision, capturing tech debt, refactoring code that may leave docs stale, auditing AGENTS.md/CLAUDE.md, setting up docs/, or asking where to document something. Covers exec plans, ADRs, design docs, and agent-readable doc structure.
---

# Docs-as-Code

**The repository is the system of record.** If a decision, plan, or constraint lives only in chat or someone's head, it doesn't exist for the agent.

---

## Context tiers

Design every doc for one tier. Hot docs crowd out the task, so they must earn every line.

| Tier | Loads | Budget | Examples |
|------|-------|--------|----------|
| **Hot** | Every session | < 200 lines total | `AGENTS.md`, `CLAUDE.md`, always-loaded rules |
| **Warm** | Task-specific | Thorough | `docs/exec-plans/active/`, `ARCHITECTURE.md` |
| **Cold** | On demand | Thorough, indexed | `docs/design-docs/`, `docs/references/` |

---

## Route to the right doc type

| Situation | Doc type | Location | Read |
|-----------|----------|----------|------|
| Plan ≥3 tasks, in progress | Exec plan | `docs/exec-plans/active/` | `references/exec-plan.md` |
| Completed plan | — | `docs/exec-plans/completed/` | `references/exec-plan.md` |
| Known tech debt / quirk | Tech debt entry | `docs/exec-plans/tech-debt-tracker.md` | `references/exec-plan.md` |
| Why a decision was made | Design doc / ADR | `docs/design-docs/<topic>.md` | `references/design-doc.md` |
| Product direction, non-goals | Product spec | `docs/product-specs/<feature>.md` | `references/design-doc.md` |
| How to use a library correctly | Reference | `docs/references/<lib>-llms.txt` | `references/agent-readable.md` |
| Module map, dependency direction | Architecture | `ARCHITECTURE.md` | `references/doc-structure.md` |
| Setting up docs/ from scratch | All | — | `references/doc-structure.md` |
| Writing or auditing AGENTS.md | Hot doc discipline | `AGENTS.md` | `references/agents-md.md` |

When in doubt: write an ADR. Decisions are the highest-value thing to capture — code shows *what*, only docs show *why*.

---

## Divergence rule

Docs that contradict code are a critical failure — an agent following stale docs confidently implements the wrong thing. **Trust the code, fix the doc.**

Triggers for a doc sweep:
- Renamed function, class, or type
- Moved file or changed module boundary
- Reversed decision
- Completed exec plan task

After **any refactor**, read `references/freshness-refactor.md`. It covers the full surface: `docs/`, `AGENTS.md`, `ARCHITECTURE.md`, JSDoc in source, test descriptions, tsconfig paths, `package.json` exports, barrel files. This is where agents most often miss things.

---

## Reference index

Load one or two at a time — don't load everything.

- **`references/doc-structure.md`** — `docs/` layout, initial scaffolding, ARCHITECTURE.md conventions
- **`references/exec-plan.md`** — exec plan template, committable-unit task rule, tech debt entry format, active → completed lifecycle
- **`references/design-doc.md`** — ADR template with Better/Worse/Must-now-be-true, rejected alternatives, product spec structure
- **`references/agent-readable.md`** — concrete-over-abstract, symptom→cause→fix tables, library reference files
- **`references/agents-md.md`** — what belongs in AGENTS.md, 100-line target, anti-patterns
- **`references/freshness-refactor.md`** — post-refactor checklist across docs, source JSDoc, configs, barrels, tests; completed-plan annotation rule
