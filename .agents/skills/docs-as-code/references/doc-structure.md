# Doc Structure

When setting up docs from scratch, or auditing an existing `docs/` tree, use this layout. It's designed for progressive disclosure: each directory maps to a context tier, so an agent loads only what it needs.

---

## Recommended layout

```
<repo-root>/
├── AGENTS.md                   # Hot — entry point, ~100 lines, table of contents
├── CLAUDE.md                   # Hot — symlink or mirror of AGENTS.md (tooling-specific)
├── ARCHITECTURE.md             # Warm — package/module map, dependency direction
├── docs/
│   ├── DESIGN.md               # Warm — product direction, phases, non-goals
│   ├── exec-plans/
│   │   ├── active/             # Warm — in-progress plans, one file per initiative
│   │   ├── completed/          # Cold — historical record, read on demand
│   │   └── tech-debt-tracker.md  # Warm — known debt, quirks, edge cases
│   ├── design-docs/            # Cold — ADRs, one file per decision
│   │   ├── core-beliefs.md     #   (optional) foundational decisions
│   │   └── <topic>.md
│   ├── product-specs/          # Cold — feature specs, one file per feature
│   │   └── <feature>.md
│   └── references/             # Cold — library usage notes, agent-readable
│       └── <lib>-llms.txt
└── .agents/ (or .claude/)
    ├── skills/                 # Skill packages (self-contained)
    └── rules/                  # Always-loaded short directives
```

Only create directories you'll populate. An empty `docs/product-specs/` is noise.

---

## What each directory is for

**`AGENTS.md` (and `CLAUDE.md`)** — The hot doc. Agents load this every session. It is NOT the documentation — it is a **map to the documentation**. Target ~100 lines. See `agents-md.md` for discipline.

**`ARCHITECTURE.md`** — The module map. "What lives where, what depends on what." Read when an agent needs to know which package a symbol belongs to, or which layer a new feature should sit in. Keep flat — one diagram, one table of packages, one paragraph per package.

**`docs/DESIGN.md`** — Product-level: where the product is heading, what phase it's in, what's explicitly out of scope. Not technical.

**`docs/exec-plans/active/`** — One file per in-progress initiative. Created when work starts, archived when done. See `exec-plan.md`.

**`docs/exec-plans/completed/`** — Historical archive. **Do not rewrite** these when code changes — annotate instead (see `freshness-refactor.md`).

**`docs/exec-plans/tech-debt-tracker.md`** — A single flat file listing known technical debt, with short entries (symptom, location, why it's deferred). Flat is intentional: agents should grep this file, not navigate subfolders.

**`docs/design-docs/`** — ADRs (Architecture Decision Records). One file per decision. These are the highest-value docs in the repo because they capture **why**, which code can never express.

**`docs/product-specs/`** — Feature specs. "What this feature is, who it's for, how success is measured." Separate from design-docs because product intent and technical decision often have different authors and lifecycles.

**`docs/references/`** — Library usage notes tailored to your project's patterns. Named `<lib>-llms.txt` by convention (agent-readable plain-text reference). See `agent-readable.md`.

---

## Initial scaffolding — when `docs/` doesn't exist yet

Create the minimum first. Don't create empty folders for hypothetical future docs.

**Minimum viable scaffold:**

```
AGENTS.md                           # Write this first (100 lines, table of contents)
ARCHITECTURE.md                     # One page: package map + dependency rules
docs/
├── exec-plans/
│   ├── active/
│   │   └── <current-initiative>.md # If work is in progress
│   └── tech-debt-tracker.md        # Empty scaffold is fine; populate as debt surfaces
└── design-docs/
    └── <first-decision>.md         # Capture one real decision, not a placeholder
```

Add `completed/`, `product-specs/`, `references/` only when you have real content for them.

---

## ARCHITECTURE.md conventions

Keep it flat and dense. Agents read this to answer "where does X belong?"

**Required sections:**
1. **Package map** — table of packages/modules with one-line purpose
2. **Dependency direction** — which layer can import from which (e.g., "core → domain → app; never reverse")
3. **Key boundaries** — any module that must stay pure / must not depend on I/O / etc.

**Avoid:**
- ASCII diagrams longer than 15 lines (they rot and resist updates)
- Class-level detail (belongs in JSDoc or design-docs)
- Historical narrative ("originally we used X, then switched to Y")  — that's ADR territory

**Example package map (Markdown table):**

| Package | Purpose | May import from |
|---------|---------|-----------------|
| `core` | Pure types, constants | (nothing) |
| `domain` | Business rules | `core` |
| `app` | Orchestration, I/O | `core`, `domain` |
| `cli` | User-facing entry | `app` |

This tells an agent where a new function belongs in ~30 seconds.

---

## Naming conventions

- Exec plan files: `<kebab-case-initiative>.md` (e.g., `auth-rewrite.md`)
- Design docs: `<kebab-case-topic>.md` (e.g., `token-storage.md`)
- Product specs: `<kebab-case-feature>.md`
- Library references: `<lib>-llms.txt` (e.g., `commander-llms.txt`)
- Dates in filenames only when the doc is time-bound (rare) — usually `Created:` in the body is enough

Consistency matters more than the specific convention. An agent uses filename patterns to build mental maps.
