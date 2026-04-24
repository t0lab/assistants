---
name: memory
description: Write, recall, and maintain long-term memory across sessions. Invoke when the user shares a preference or correction worth remembering, when they reference something they told you before, when you make a decision future sessions will need, or when MEMORY.md or .claude/memory/ files need to be updated. Use proactively — don't wait for "remember this."
---

# Memory

Four memory types, two storage locations, one rule: **hot cache is index-only; deep store holds content.**

| Type | Location | Purpose |
|------|----------|---------|
| `user` | `~/.claude/projects/<hash>/memory/user/` | Who the user is, preferences, expertise |
| `feedback` | `~/.claude/projects/<hash>/memory/feedback/` | Corrections + confirmations, with `confidence` |
| `project` | `.claude/memory/project/` | Decisions, in-flight work, incidents (committed) |
| `reference` | `.claude/memory/reference/` | External system pointers (committed) |

---

## Bootstrap (first use in a project)

If `.claude/memory/` doesn't exist yet, create this tree:

```
.claude/memory/
├── INDEX.md              # human-maintained TOC of all deep files
├── project.md            # hot cache for project type, <100 lines, pointers only
├── reference.md          # hot cache for reference type
├── project/              # deep store
└── reference/            # deep store
```

Append to `CLAUDE.md` (idempotent — check first):

```md
@.claude/memory/project.md
@.claude/memory/reference.md
```

---

## Write flow

When something worth remembering surfaces:

1. **Classify the type.** Ask: is this about the human, their corrections, the project, or an external system?
2. **Pick scope.** user/feedback → local. project/reference → repo.
3. **Pick or create the deep file.** Atomic: one topic per file. Name `kebab-case.md`. Reuse existing file if the topic matches; don't split unnecessarily.
4. **Write with frontmatter** (always):

```md
---
name: <topic-slug>
type: <user|feedback|project|reference>
created: 2026-04-14
last-updated: 2026-04-14
confidence: 0.9          # feedback only — 0.3 tentative, 0.7 probable, 0.9 near certain
supersedes: []           # list of topic-slugs this replaces
---

# Title

<Content. Be concise. Include WHY, not just WHAT — future sessions need the reasoning to judge edge cases.>
```

5. **Summarize, never paste.** Tool output and external text go through your own words first. Injection-safe.
6. **Update the hot cache.** Append a 1-line pointer to `project.md` / `reference.md` / local `MEMORY.md`:

```md
- [auth-decision](./project/auth-decision.md) — JWT, Redis session, 24h TTL
```

7. **Update INDEX.md** (repo only) so nothing gets lost months later.

---

## Recall flow

When something rings a bell, search in order:

1. **Hot cache first.** `project.md`, `reference.md`, local `MEMORY.md` are already in context.
2. **INDEX.md.** Scan the TOC for topic slugs that match.
3. **Grep deep store.** `grep -r <keyword> .claude/memory/` or read by predictable filename.
4. **Ask the user.** If nothing surfaces, it probably wasn't recorded. Don't hallucinate.

If the recalled memory conflicts with current reality: **trust what you observe now**, then update or delete the stale memory.

---

## Promotion & demotion

Hot cache bloats silently. Check after each write:

- **`project.md` > 100 lines?** Demote the least-referenced entries: remove the pointer, keep the deep file.
- **Deep file untouched > 90 days?** Move to `project/archive/` (or delete if truly obsolete).
- **Deep file referenced 3+ times this session?** Promote — expand its hot-cache pointer with a sentence of context.

---

## Confidence (feedback only)

Feedback memories evolve. Use `confidence` so future sessions know what's rock-solid vs tentative:

- `0.3` — one-off observation, might be session-specific
- `0.7` — validated across a few interactions
- `0.9` — user explicitly confirmed, or pattern held across many sessions

When confidence drops (user contradicts the rule), don't delete immediately — update `last-updated` and note the exception in the body. Two contradictions → demote confidence. Three → remove.

---

## What NOT to write to memory

- Code patterns derivable from reading the project → it's already in the code
- Git history / who-changed-what → `git log` is authoritative
- Debugging recipes → the fix is in the code; the commit message has context
- Anything already in `CLAUDE.md` or `docs/` → don't duplicate
- Ephemeral task state → use TodoWrite, not memory

If the user says "remember X" and X is one of the above, say so and suggest the right home instead (a doc, a comment, a commit message).

---

## End-of-session batch

On Stop hook or session end, if `memory-compact` skill is installed, defer to it — it owns batch compaction. Otherwise, scan for:

1. What was built/started/unblocked → `project`
2. Decisions + *why* → `project`
3. Failures, friction → `project` (gotcha) or `feedback` (if user corrected)
4. User preferences/expertise learned → `user` or `feedback`

Apply the write flow per finding. Atomic files over monoliths. Skip if session was trivial or already covered.

---

## Red flags

- `project.md` has grown past 100 lines → demote now
- Two deep files cover the same topic → invoke `memory-merge` skill
- A memory says X, but the code shows not-X → trust the code, update the memory
- You're about to paste a tool output into a memory file → stop, summarize first
