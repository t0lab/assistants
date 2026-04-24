---
name: context-discipline
description: Context hygiene and task decomposition for long AI sessions — invoke when planning a large feature, when context-fatigue signs appear (same file read 3+ times, errors accumulating, task spanning multiple sessions), before starting a multi-session task, or when the user asks how to break down a complex task. Use this proactively when a task looks too large to finish in one shot.
---

# Context Discipline

Two practices: **context hygiene** (keeping the current session clean) and **task decomposition** (breaking large work into session-sized chunks).

---

## Context Hygiene

The context window is finite and quality degrades as it fills. A stale context — full of old error messages, large file dumps, abandoned branches of reasoning — costs tokens and dilutes responses.

### Read targeted, not wholesale

Prefer reading what you actually need:
```
# Bad: dumps 800 lines for a 3-line fix
Read the entire file

# Good: read the relevant function
Read lines 120–145
```

Use `Grep` to locate before reading. Use `Read` with `offset`/`limit` to get only the relevant section. Only read the full file when the task genuinely requires understanding the whole thing.

### Signal context switches clearly

Each session works best when it has a single clear purpose. When the task shifts to something unrelated:
- `/clear` — wipes context entirely, start fresh
- `/compact` — compresses history in-place when you want to keep some continuity but need to free space

Use `/compact` before starting a large implementation phase in an ongoing session. Use `/clear` when switching from one feature to an unrelated one.

### Don't let errors accumulate

After a failed attempt, don't pile on more attempts in the same thread. Pause, diagnose the root cause, then re-engage with a clean read of the actual state. Three failed attempts in a row is a signal to `/clear` and start fresh with what you now know.

---

## Task Decomposition

When a task is too large to complete cleanly in one session, decompose it before starting. Attempting a 2,000-line feature in one shot leads to half-finished work, context overflow, and hard-to-review diffs.

### The right chunk size

A well-sized chunk:
- Produces a reviewable, committable diff (ideally < 400 lines)
- Has a clear "done" condition you can verify
- Can be completed without context overflow
- Leaves the codebase in a working state when finished

### How to decompose

Split along natural seams — don't create arbitrary cuts:

| Split by | When to use |
|----------|-------------|
| **Type/interface boundary** | New types and schemas before logic that uses them |
| **Layer boundary** | Data layer → business logic → API → UI |
| **Feature phase** | Spec/plan → core implementation → tests → integration |
| **File boundary** | One module or component at a time |

Avoid splitting mid-function or mid-feature in a way that leaves tests failing or the build broken.

### Decomposition template

Before starting a large task, write this out (even just in your head):

```
Task: <what needs to be done>

Chunk 1: <what, done condition, expected diff size>
Chunk 2: <what, done condition, expected diff size>
Chunk 3: <what, done condition, expected diff size>

Dependencies: Chunk 1 must land before Chunk 2 (reason)
```

Share the decomposition with the user before starting. A 2-minute alignment on the plan prevents 2-hour rework.

### Session handoff

At the end of each chunk, leave a clean handoff:
- Commit what's done with a clear message
- Note what's next (in a comment, commit message, or memory-compact)
- The next session reads the commit history and current state — not your recollection

```bash
git log --oneline -5   # what was done
git status             # what's in progress
```

---

## Red flags to watch for

These are signs to stop, decompose, or clear context:

- The task has been "almost done" for more than 2 sessions
- You've read the same file 3+ times in a session
- Error messages from early in the session are still in context
- The user has added 4+ new requirements mid-session without a plan
- You're about to make a breaking change to stabilize another breaking change

When you hit a red flag: surface it to the user, agree on scope, then either clear and restart or close the current chunk before opening the next.
