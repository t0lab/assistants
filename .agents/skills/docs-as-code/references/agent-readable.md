# Agent-Readable Docs

Docs written for humans often fail agents. Humans skim, infer, and fill gaps from experience. Agents read literally and act on what they find. This reference covers the principles that make docs actually usable when the reader is an LLM.

---

## Core principles

### 1. Concrete over abstract

**Weak (abstract):**
> The auth layer should handle tokens carefully to ensure security.

**Strong (concrete):**
> All session tokens must go through `SessionStore.create()`. Direct inserts into the `sessions` table bypass the audit log. See `docs/design-docs/session-storage.md`.

An agent can act on the second. It cannot act on the first without guessing.

Rules of thumb:
- Name the file / function / symbol, not the concept
- State the rule, not the philosophy
- Show the invariant, not the intent

### 2. Symptom → cause → fix

When documenting known issues, bugs, or quirks, use a three-column or three-line structure. This is the shape an agent needs when it hits an error.

**Weak:**
> Sometimes the build fails due to cache issues. Try clearing the cache.

**Strong:**

| Symptom | Cause | Fix |
|---------|-------|-----|
| `ERR_CACHE_MISS` during `pnpm build` | Stale tsup cache after TS config change | `rm -rf packages/*/dist packages/*/.tsup` |
| Tests hang on `SessionStore.create()` | Missing `DATABASE_URL` in test env | Source `.env.test` before `pnpm test` |

An agent hitting the symptom finds the fix in one lookup.

### 3. Link, don't duplicate

Duplicate docs drift. When information lives in two places, one will be wrong within months — and the agent will trust the wrong one.

- AGENTS.md mentions a convention → link to the rule file or ADR
- README gives quick start → link to the full guide
- Exec plan references a decision → link to the ADR

If you find yourself copying a paragraph between files, replace the copy with a link. Single source of truth, every time.

### 4. Stable anchors

Agents often quote file paths and line numbers. Keep anchors stable:
- Use headings as anchor targets (`#consequences`), not line numbers
- Link to files by path, not to specific lines unless the line is structurally stable (like a constant export)
- When a doc is reorganized, keep old heading redirects for one version cycle

---

## Library reference files (`<lib>-llms.txt`)

When a library is used repeatedly in project-specific ways, write a short reference agents can load on demand. Put these in `docs/references/`.

**Purpose:** Not to replace the library's docs — to capture **how this project uses it**.

**Template:**

```markdown
# <library> — usage in this project

**Library:** <name + version>
**Where we use it:** <packages / modules>

## Project conventions

- We always <specific pattern>
- We never <specific anti-pattern>, because <reason>
- Import from <specific subpath>, not the default export, because <reason>

## Common tasks

### <Task 1: e.g., "Add a new CLI command">

```ts
// Minimal working example tailored to this project's structure
```

Notes:
- <Gotcha specific to our setup>

### <Task 2>

...

## Known quirks
- <Quirk> — workaround: <specific fix>
- <Quirk in version X.Y> — upgrade path: <path>
```

Keep these focused. A 5-page reference won't get read; a 1-page one will.

---

## Writing for progressive disclosure

Assume the reader only has the current doc in context. Don't assume they've read the design doc you're referencing unless you link it.

**Pattern:**
1. State the rule / fact in one sentence
2. Give the minimum context needed to understand it
3. Link to deeper sources

**Example:**

> **Rule:** All session writes go through `SessionStore`.
>
> This is because the `sessions` table has an audit-log trigger that only fires for reads issued by the store (see `docs/design-docs/session-storage.md#must-now-be-true`). Direct `INSERT` breaks compliance reporting.
>
> Full rationale: `docs/design-docs/session-storage.md`.

The reader who only needs the rule stops at line 1. The reader who needs to know why reads the paragraph. The reader who wants the full debate follows the link.

---

## Anti-patterns

**Walls of prose.** If the doc has no lists, tables, or headings for 10+ lines, agents will skim and miss things. Break it up.

**Vague verbs.** "Handle", "manage", "process", "deal with" — tell you nothing. Replace with what actually happens: "validate", "transform into X", "persist to Y".

**Hedged language.** "Generally", "usually", "typically" — signal that there's an exception you haven't documented. Find the exception and document it, or drop the hedge.

**Future tense.** "We will add X" doesn't age. Use present tense for what's true now, past tense for decisions already made, and explicit dates for plans.

**Unlabeled examples.** Code blocks without a one-line caption leave the reader guessing what they're looking at.
