---
name: memory-merge
description: Resolve conflicts and consolidate duplicate memories in .claude/memory/. Invoke after git pull surfaces conflict markers in memory files, when two memory files cover overlapping topics, when project.md hot cache has grown past ~100 lines, or when the user asks to "clean up memory" / "merge memories". Do not run proactively without a trigger — merging rewrites team-shared files.
---

# Memory Merge

`.claude/memory/` is committed, so multiple devs (and their agents) write in parallel. Conflicts and duplicates are expected. This skill resolves them without data loss.

The guiding rule: **zero knowledge loss, minimum redundancy, maximum scannability.** Every merge is a curation step, not a concat.

---

## When to invoke

- `git status` shows conflict markers in `.claude/memory/`
- Two deep files clearly cover the same topic (e.g., `auth.md` + `auth-decision.md`)
- `project.md` or `reference.md` exceeds ~100 lines
- User asks to clean up, consolidate, or prune memory

Do NOT invoke speculatively. Merging without a trigger risks rewriting valid team memory.

---

## Merge flow

### 1. Detect

Run one of:

```bash
git diff --name-only --diff-filter=U .claude/memory/    # conflicted files
grep -r '<<<<<<<' .claude/memory/                       # any stray markers
wc -l .claude/memory/project.md .claude/memory/reference.md  # hot cache size
```

Cross-reference: for each topic slug in a conflicted/oversized file, grep the rest of `.claude/memory/` for overlapping topics.

### 2. Classify

| Pattern | Meaning | Resolution |
|---------|---------|------------|
| Same file, different section | Additive conflict (both devs added content) | Keep both, re-sort |
| Same section, different phrasing | Semantic duplicate | Merge into one paragraph, preserve richer detail |
| Same section, conflicting content | One is stale or wrong | Use `last-updated` + `authors` + code reality to decide winner; mark loser with `supersedes` or delete |
| Two separate files, same topic | Duplicate topic | Consolidate into the better-named file; the other gets `supersedes: [kept-slug]` and is deleted |

### 3. Propose

Show the user a diff plan **before writing**:

```
proposal:
  keep:   .claude/memory/project/auth-decision.md (richer, last-updated 2026-04-10)
  drop:   .claude/memory/project/auth.md (older, last-updated 2026-03-01)
  merge:  2 sentences from dropped file into kept file's "Trade-offs" section
  index:  remove auth.md pointer from project.md
```

Await approval unless the conflict is purely syntactic (e.g., both devs added different pointers to `project.md` — safe to keep both).

### 4. Apply

- Update `last-updated` on the surviving file
- Append dropped file's slug to `supersedes: [...]`
- Delete the dropped file (`git rm`)
- Update `project.md` / `reference.md` hot cache — remove dead pointers, keep the canonical one
- Update `INDEX.md` TOC

### 5. Verify

```bash
grep -r '<<<<<<<' .claude/memory/                # no markers left
wc -l .claude/memory/project.md                  # within budget
git diff --stat .claude/memory/                  # review scope before commit
```

---

## Consolidating oversized hot cache

When `project.md` exceeds ~100 lines without a conflict:

1. Identify the least-referenced pointers (ask user, or use heuristic: oldest `last-updated` on the deep file)
2. Remove those pointers from `project.md`
3. Leave deep files intact — recall via `INDEX.md` + grep still works
4. If a deep file is also >90 days stale, move to `project/archive/` or delete if obsolete

---

## Safety rules

- **Never merge conflicts without user approval** unless the conflict is additive and non-semantic
- **Never delete without `supersedes` trail or explicit user OK** — memory deletion is hard to audit
- **Never mass-regenerate** memory files — edits only, preserve authorship and timestamps
- **Commit the merge as its own commit** — don't bundle with feature work. Message: `chore(memory): consolidate <topic>`

---

## Pairs with

- `memory` skill — invoked on write, this skill on consolidate
- `memory-compact` skill — end-of-session compaction; merge-conflict resolution is different from compaction, don't confuse

---

## Red flags

- The merge would drop a memory with `confidence: 0.9` → stop, show user
- The conflict spans >5 files → probably a bad merge upstream, investigate before consolidating
- `supersedes` chains forming loops (A→B→A) → someone's merging in a loop; reset to latest timestamp
