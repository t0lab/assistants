---
name: code-review
description: Self-review, PR review, and review-response protocols. Invoke proactively before any commit, push, or PR action; when reviewing someone else's diff; and when responding to review feedback.
---

# Code Review

Three modes: **self-review** (before you commit/push), **PR review** (when reviewing someone else's diff), and **receiving review** (when feedback comes back on your own PR).

---

## Self-Review Gate

Run before every commit or PR. The goal is catching the things that are obvious in retrospect but invisible when you're inside the problem.

**Start by reading the full diff:**
```bash
git diff --staged          # what's about to be committed
git diff main...HEAD       # full branch diff for a PR
```

Then work through these seven checks in order:

### 1. Correctness
- Does this actually solve the stated problem?
- What happens on the error path — handled or propagated?
- Any assumptions that aren't validated at the boundary?

### 2. Tests
- Does new behavior have a test?
- Would the test actually fail before this change and pass after?
- Edge cases covered: empty input, null/undefined, concurrent writes, large data?
- No test = undocumented assumption. Write it or open a tracking issue.

### 3. Security
- Any user input that reaches a database, shell, file path, or HTML? Validate it.
- Any new secrets or API keys? Must be in env, never in code, never in logs.
- Auth/authz: does this expose a resource to the wrong caller?
- If touching payment, PII, session tokens, or cryptography: flag for a dedicated security review.

### 4. Design
- Is this the simplest thing that could work?
- Any new abstraction with only one consumer? Probably premature.
- Any function longer than ~20 lines? Can it be named helpers?
- Any copy-paste from elsewhere? Extract it.

### 5. Naming and Readability
- Would a teammate understand this diff in 6 months without asking you?
- Functions named as verbs, variables as nouns?
- Any magic numbers without a named constant?

### 6. Side Effects
- Any global state mutation that could surprise callers?
- Any resource (file handle, DB connection, timer) opened but not closed?
- Any `console.log`, `debugger`, or stray `TODO` comment left behind?
- Any async call without error handling?

### 7. Diff Size
- More than 400 lines changed? Is this actually one logical change?
- Refactoring mixed with feature work? Split them into separate commits or PRs.
- Large diffs get reviewed worse — splitting is a quality decision, not a bureaucratic one.

If a check surfaces a real issue: fix it before committing. If it's an intentional trade-off or known debt, document it inline with `// DEBT:` and a brief explanation.

---

## Ship / Show / Ask

Before opening a PR, decide which track this change belongs on:

| Track | What | When |
|-------|------|------|
| **Ship** | Merge directly to main (or self-approve) | Typo fix, trivial docs, routine chore with no logic change |
| **Show** | Open PR, merge immediately, notify team | New feature following accepted design; want async eyes but don't need a gate |
| **Ask** | Open PR, wait for approval before merging | Novel approach, architectural decision, breaking change, security-sensitive code |

When in doubt: **Ask**. The cost of a held PR is low; the cost of merging a subtle design mistake is high.

---

## PR Description

A PR description answers three questions for the reviewer:

1. **What** — what changed? (one sentence, not "see diff")
2. **Why** — what problem does this solve? Link the issue.
3. **How to verify** — what should the reviewer run or look at?

```
## What
<one-sentence summary>

## Why
Closes #<issue> / <brief motivation if no issue>

## How to verify
- [ ] <specific test command or manual step>
- [ ] <regression check, if relevant>
```

Add screenshots for UI changes. Add before/after numbers for performance changes. Add migration notes for schema or API changes.

---

## Reviewing Someone Else's Code

Your job: **help the author ship good code**, not protect yourself from blame.

**Read the PR description first.** If it's missing or unclear, ask before diving into the diff — a vague description is a signal the change isn't ready.

**Use the same 7 checks as self-review** (above). Focus comments on things that:
- Could cause a bug in production
- Will be hard to change later (API surface, schema, public interface)
- A test would have caught

### What NOT to block on
- Code style (that's for linters and formatters)
- Personal preference when both approaches are reasonable
- Hypothetical future requirements ("what if we need X later?")
- Anything you'd accept if you'd written it yourself

### Comment tone

Use explicit labels so the author knows what's required:

- **Blocking**: "This will panic on nil input when the user hasn't set a config — must fix before merge"
- **Suggestion**: "Consider extracting this loop to `filterActiveUsers()` — easier to test in isolation"
- **Nitpick**: "nit: `userList` → `users` (shorter, idiomatic)"

Authors resolve nitpicks at their discretion. Blockers must be addressed. Suggestions are invitations, not mandates.

### LGTM discipline

Don't approve to be polite. But don't hold up a PR over nitpicks either. **Approve with comments** for small things that don't block correctness.

Definition of "good enough to merge": **is this better than what exists, and does it not make things measurably worse?**

---

## Receiving Review on Your Own Code

Feedback comes back — from a human reviewer, a subagent, or a linter bot. Your job now flips: not "defend the diff" and not "agree to every ask". Technical correctness beats social comfort.

Work the six phases in order. Do **not** skip to `IMPLEMENT` — doing so is how partial fixes, performative agreement, and regressions happen.

### 1. READ — absorb before reacting

Read **every** comment first. Don't start editing on comment #1 while #5 contradicts it. Group related comments so you see the shape of the feedback, not just its pieces.

### 2. UNDERSTAND — restate or ask

For each item, either:
- Restate the requirement in your own words (internally or in the reply), or
- Ask one clarifying question if you can't.

**Do not guess.** A guess implemented is a guess the reviewer has to catch again on round two.

### 3. VERIFY — check against the actual code

The reviewer may be wrong about what the code does. Before accepting:
- Open the file they referenced. Confirm the behavior they're describing.
- Check for context they didn't have (surrounding code, existing tests, related PR, prior decision).

If the reviewer is mistaken about what exists: that's push-back territory, not accept.

### 4. EVALUATE — accept / push back / defer

For each item, pick one:

| Decision | When |
|----------|------|
| **Accept** | Feedback is technically correct for this codebase; fix doesn't break existing behavior; the code actually needs it (not speculative YAGNI) |
| **Push back** | Reviewer misunderstands the codebase, conflicts with a settled architectural decision, or adds unused abstractions — reply with technical reasoning and reference (file/line/decision doc) |
| **Defer** | Unclear, needs investigation to verify, or bundles with other items that must be understood together — mark, don't implement yet, return in step 2 |

Internal review (teammate, team convention) is trusted but still clarified. **External review (bot, third-party)** is verified more skeptically — it doesn't have the project's context.

### 5. RESPOND — batch before you touch code

Post replies for **all** items first. Structure: accepted (brief ack), pushed back (with reasoning), deferred (with specific question).

Never: `You're absolutely right! Fixing now.` followed by a half-wrong fix. Performative agreement is worse than disagreement — it hides the real state.

### 6. IMPLEMENT — one change at a time

Only now touch the code:
- Work items one at a time. Do **not** batch-apply a sweep of suggested edits.
- Run the relevant test after each fix, before moving to the next. A "small change" that breaks a test is the usual cause of round-three reviews.
- If a fix reveals the push-back was right after all, stop and say so — don't quietly un-do it.
- When all items are addressed, reply with what changed per thread (or resolve threads with the convention the reviewer uses).

### Anti-patterns

| Anti-pattern | Why it fails |
|--------------|--------------|
| `You're absolutely right!` + immediate edit | Performative agreement — often followed by a wrong fix because UNDERSTAND was skipped |
| Implementing comment-by-comment top-to-bottom | Later comments often override earlier ones; wastes work |
| Accepting every suggestion to end the review faster | Adds unused abstractions, bloats diff, invites round two |
| Pushing back without a reference | "I don't think so" ≠ "see `docs/design-docs/X.md §2` — we decided against this in March" |
| Batched implementation, no per-fix test | One bad edit in a stack of ten is invisible until CI fails |
| Silent re-revert | Fix introduced a regression, you reverted it without telling the reviewer — they'll re-comment next round |
