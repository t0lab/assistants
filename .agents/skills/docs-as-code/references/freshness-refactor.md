# Post-Refactor Freshness Checklist

After any refactor that renames, moves, removes, or changes the shape of a public symbol, stale docs become **actively harmful** — an agent following stale guidance will confidently implement the wrong thing.

This reference covers the **full surface area** that can drift: not just `docs/`, but also source-level documentation (JSDoc), config files (tsconfig paths, package.json exports), barrel files, and test descriptions. Agents often miss these when they only think "update the docs."

Use this as a grep-driven checklist. For each section, run the provided search, then act on hits.

---

## Before you start — collect the old and new names

Write them down explicitly. You'll use these strings repeatedly.

```
Old: <OldName>, <old/path/segment>, <oldMethodName>
New: <NewName>, <new/path/segment>, <newMethodName>
```

---

## 1. Documentation surface

### `AGENTS.md` / `CLAUDE.md`

```bash
grep -n "OldName\|old/path\|oldMethodName" AGENTS.md CLAUDE.md
```

- [ ] Routing table entries updated
- [ ] Any inline code examples updated
- [ ] Rule bullets that cite old name updated

### `ARCHITECTURE.md`

```bash
grep -n "OldName\|old/path" ARCHITECTURE.md
```

- [ ] Package/module table reflects new names
- [ ] Dependency direction rules still hold (or are updated)
- [ ] Any ASCII diagrams re-drawn or removed

### `docs/exec-plans/active/`

```bash
grep -rn "OldName\|old/path\|oldMethodName" docs/exec-plans/active/
```

- [ ] Tasks referencing old names updated
- [ ] Decisions log gets a new entry noting the rename
- [ ] File paths in "Files:" hints updated

### `docs/exec-plans/completed/` — **annotate, do not rewrite**

```bash
grep -rn "OldName\|old/path\|oldMethodName" docs/exec-plans/completed/
```

**Do NOT edit the body** of a completed plan. It is historical record.

Instead, add a dated annotation at the top:

```markdown
> **Note (2026-04-14):** `OldName` was renamed to `NewName` and moved from
> `src/old/path/` to `src/new/path/` after this plan completed. Code references
> in the tasks below reflect the state at time of completion.
```

Why the distinction: rewriting completed plans destroys the historical trail that explains "what we knew when we decided." An agent reading a completed plan expects it to match the code of that era, and uses git history to see the present.

### `docs/exec-plans/tech-debt-tracker.md`

```bash
grep -n "OldName\|old/path\|oldMethodName" docs/exec-plans/tech-debt-tracker.md
```

- [ ] Entry locations (`src/old/path/file.ts:42`) updated to new paths/lines
- [ ] If the debt is resolved by the refactor, remove the entry (with a note in the commit)

### `docs/design-docs/`

```bash
grep -rn "OldName\|old/path\|oldMethodName" docs/design-docs/
```

- [ ] Active ADRs updated in place
- [ ] If the refactor **reverses** an ADR decision: mark old ADR `superseded by <new-file>.md` and write a new ADR explaining why
- [ ] "Must now be true" invariants checked — do they still hold with new names?

### `docs/product-specs/` and `docs/references/`

```bash
grep -rn "OldName\|old/path\|oldMethodName" docs/product-specs/ docs/references/
```

- [ ] Code examples in library references updated
- [ ] Any feature spec mentioning the renamed symbol updated

### `README.md` and `CONTRIBUTING.md`

```bash
grep -n "OldName\|old/path\|oldMethodName" README.md CONTRIBUTING.md
```

- [ ] Quick start commands and imports updated

---

## 2. Source-level documentation (often missed)

Agents frequently skip this layer. It's the difference between a "good" update and a complete one.

### JSDoc / TSDoc in source files

JSDoc comments reference symbols in prose. Type renames don't automatically update comment text.

```bash
grep -rn "OldName\|oldMethodName" --include="*.ts" --include="*.tsx" --include="*.js"
```

Focus on:
- [ ] `@param`, `@returns`, `@throws` descriptions that name the old type
- [ ] `@see` tags pointing to renamed/moved files
- [ ] `@example` blocks with old import paths or old method calls
- [ ] Free-text comments like `// UserRepository caches by email` after `UserRepository` becomes `UserStore`

### Test descriptions

Test names appear in CI output and error messages. Stale names make failures confusing.

```bash
grep -rn "OldName\|oldMethodName" --include="*.test.ts" --include="*.spec.ts" --include="*.test.tsx"
```

- [ ] `describe('OldName', ...)` → `describe('NewName', ...)`
- [ ] `it('OldName.foo does X', ...)` → updated
- [ ] Helper variable names inside tests (less critical but worth a sweep)
- [ ] Fixture file names if they encode the old name

### Error messages and log strings

User-facing and operator-facing strings that name the symbol:

```bash
grep -rn "OldName\|oldMethodName" --include="*.ts" --include="*.tsx" -l
```

- [ ] `throw new Error('OldName not initialized')` → updated
- [ ] Log lines (`logger.info('OldName started')`) — update or accept that logs change across the rename boundary

---

## 3. Configuration and build surface

These files rarely get searched after a refactor, but they're where rename failures produce the most confusing symptoms (builds pass, imports silently resolve to stubs, etc.).

### `tsconfig.json` (and variants)

```bash
grep -n "old/path\|OldName" tsconfig*.json packages/*/tsconfig*.json
```

- [ ] `paths` aliases — `"@/old-path/*"` entries removed or renamed
- [ ] `references` entries (project references) point to renamed directories
- [ ] `include` / `exclude` globs don't reference removed paths

### `package.json` files

```bash
grep -n "old/path\|OldName" package.json packages/*/package.json
```

- [ ] `exports` field — subpath exports updated (`"./old-module"` → `"./new-module"`)
- [ ] `main`, `module`, `types` paths
- [ ] Script names that encode the symbol (`"test:old-name": "..."`)

### Barrel files (`index.ts`)

Barrels re-export symbols. When a rename happens, the barrel still exports the old name or imports from the old path.

```bash
grep -rn "OldName\|old/path" --include="index.ts"
```

- [ ] `export { OldName } from './old-path'` → updated
- [ ] `export * from './old-path'` — check that path still exists
- [ ] Decide: keep a compat re-export (`export { NewName as OldName }`) for one release, or break cleanly. If keeping, document the deprecation.

### Build / bundler config

```bash
grep -rn "old/path\|OldName" \
  tsup.config.* vite.config.* webpack.config.* rollup.config.* \
  vitest.config.* jest.config.* 2>/dev/null
```

- [ ] Entry points
- [ ] Alias config
- [ ] External dependency patterns

### CI and tooling config

```bash
grep -rn "old/path\|OldName" .github/ .gitlab-ci.yml .circleci/ 2>/dev/null
```

- [ ] Workflow paths that reference old directories
- [ ] Cache keys that encode package names

---

## 4. Final sweep — catch-all

After working through the sections above, one broad search catches anything missed:

```bash
grep -rn "OldName\|old/path\|oldMethodName" \
  --exclude-dir=node_modules \
  --exclude-dir=.git \
  --exclude-dir=dist \
  --exclude-dir=.turbo \
  --exclude-dir=coverage
```

Any remaining hits should be either:
- Intentional (completed-plan annotations, deprecation notes, changelog entries) — leave with a dated comment
- Truly stale — fix

---

## Why this checklist is this long

Because agents (and humans) systematically under-scope "update the docs." The benchmark for this skill's earlier iteration showed a real case: the baseline caught `docs/` but missed JSDoc, tsconfig paths, barrel exports, and test descriptions. The skill caught the completed-vs-active distinction but missed the source-level layer.

A refactor is complete when **grep for the old name returns only intentional hits.** Nothing less.

---

## Self-review before declaring the sweep complete

The most common failure mode here is "declared done after `docs/` only." Before saying the refactor is documented, walk this list.

- [ ] **All four sections walked.** Not just `docs/` — also source-level (JSDoc, tests, error strings), config (tsconfig, package.json, barrels), and the catch-all final sweep.
- [ ] **Completed plans were annotated, not edited.** Re-read any hits in `docs/exec-plans/completed/` — body must be unchanged; only a dated note added at top.
- [ ] **Active plans reference the rename in their Decisions log.** The next agent picking up the plan needs to know the rename happened.
- [ ] **ADR supersession handled if the refactor reversed a decision.** Old ADR marked `superseded by <new>.md`; new ADR exists and explains why.
- [ ] **"Must now be true" invariants re-checked.** A rename can quietly break an invariant ("All reads go through `UserRepository`" is meaningless if `UserRepository` no longer exists; it's now `UserStore`).
- [ ] **Final catch-all grep returns only intentional hits.** Each remaining hit is either an annotation, a deprecation note, or a changelog entry — and is dated.

If any box is unchecked, the sweep is not done — you've just shifted the breakage from "stale doc" to "agent thinks the docs are fresh."
