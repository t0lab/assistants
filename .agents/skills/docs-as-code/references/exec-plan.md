# Exec Plans

An exec plan is a living document for work in progress. Its job: let any agent (human or AI) resume the work mid-stream without a meeting.

The baseline benchmark showed that agents without this skill default to **week/phase organization** (Week 1, Week 2...). That looks reasonable to a human skimming, but it's hostile to an agent mid-sprint: there's no committable unit to pick up, no explicit done condition, no record of why decisions were made. This reference exists to counter that default.

---

## Spec-first gate (do this before opening the template)

An exec plan answers **what gets built and in what order**. It does not answer **why this shape and not another**. If the "why" lives only in chat or in your head, the plan is half-built — the next agent picking it up has tasks but no context to push back when something looks off.

Before writing tasks, check what already exists:

- **Is there a design doc / ADR for the technical shape?** (e.g., "we chose JWT + opaque refresh because…")
- **Is there a product spec for the user-facing scope?** (e.g., "auth covers register/login/2FA, not SSO")

If **either is missing and the decision is non-trivial**, create it first (see `design-doc.md`). Then reference it from the plan's Background and Decisions log. Cross-reference is the whole point — the plan stays scannable, the rationale lives somewhere it can be revisited.

A decision is non-trivial if any of these are true: it creates an invariant other code must respect, reasonable engineers would disagree, or you'd be annoyed if someone undid it without talking to you. (Same trigger as `design-doc.md` — write the ADR.)

If the work is genuinely small (single committable unit, no architectural choice), skip the spec — but say so in Background ("No design doc; mechanical change."). Silence reads as oversight.

---

## Template

Copy this into `docs/exec-plans/active/<initiative>.md`:

```markdown
# <Initiative name>

**Status:** active
**Created:** 2026-04-14
**Owner:** <name / team>

## Goal
<One sentence. What will be true when this is done?>

## Background
<2–5 sentences. Why is this happening now? What constraint or decision triggered it?
An agent resuming this plan in 3 weeks needs this to make sense of the tasks.>

## Tasks

- [ ] Task 1 — <specific deliverable>
  - Done when: <observable condition>
  - Files: <expected touch points>
- [ ] Task 2 — ...

## Decisions log
- 2026-04-14: Chose X over Y because <reason>. See `docs/design-docs/<topic>.md`.

## Blockers
<None | or: waiting on <person/thing> as of <date>>

## Out of scope
<Explicit non-goals. This prevents scope creep and signals what NOT to touch.>
```

All fields earn their place:
- **Created date** — so an agent can judge whether the plan is stale
- **Background** — so resuming requires no external context
- **Decisions log** — so reversals don't get lost in git history
- **Blockers** — so an agent doesn't burn time on something that's stuck waiting
- **Out of scope** — so an agent doesn't helpfully "fix" something you deliberately deferred

---

## Task granularity — the committable-unit rule

A task should correspond to roughly one commit. If "done" requires multiple PRs or multiple days, split it.

**Bad (phase-level):**
> - [ ] Week 1: Implement JWT — token module, signing, verification, refresh tokens

**Good (committable):**
> - [ ] Add JWT signing/verification module (`src/auth/jwt.ts`)
>   - Done when: `signToken()` and `verifyToken()` exported with tests
> - [ ] Add refresh token rotation
>   - Done when: `rotateRefreshToken()` handles reuse detection, tests cover replay case
> - [ ] Wire JWT middleware into Express app
>   - Done when: `/protected` routes reject missing/expired tokens

Why this matters: an agent picking up the work mid-stream reads the checklist and knows **exactly what to commit next**. Phase-level tasks force re-planning on every resume.

**Heuristics for "is this task the right size?":**
- Could I finish it and push a commit today? → probably right
- Does it touch one coherent area? → probably right
- Does describing it require "and"? → split it
- Could two people work on it in parallel without conflict? → split it

**Banned phrasings — rewrite before committing the plan:**

These phrasings consistently produce tasks an agent cannot pick up. If you catch yourself writing them, rewrite to a concrete deliverable + observable done condition.

| Banned | Why it fails | Rewrite |
|--------|-------------|---------|
| "Implement X module" | No surface, no done condition | "Add `signAccessToken()` and `verifyAccessToken()` in `src/auth/jwt.ts`; tests cover expired / malformed / wrong-signature" |
| "Add appropriate error handling" | "Appropriate" is not testable | "Wrap DB calls in `src/auth/store.ts`; on `UniqueViolation` return `{ ok: false, code: 'duplicate' }`; integration test covers duplicate email" |
| "Handle edge cases" | Which ones? | List them: "Empty input returns 400; missing field returns 422; oversized body (>1MB) returns 413" |
| "Polish / clean up X" | Open-ended; never done | Name the file and the change: "Extract `validatePayload()` from `routes/login.ts`; no behavior change; existing tests still pass" |
| "Investigate / spike X" | Spikes belong in a branch, not a plan | If exploration is needed, write the spike as its own short task: "Spike: 1-day timebox, output is a paragraph in Decisions log on whether to use library X" |
| "Similar to Task N" | Forces re-reading; rots when N changes | Write the task fully. Repetition is cheaper than indirection. |
| "Refactor X for clarity" | "Clarity" is taste; no done condition | State the structural change: "Move `validateEmail()` from `routes/register.ts` to `src/auth/validators.ts`; update 3 call sites" |

The general rule: if the task could mean five different things to five different agents, it's not a task — it's a topic. Topics belong in Background, not Tasks.

---

## Done conditions must be observable

"Implement auth" is not a done condition. "`POST /login` returns a JWT on valid creds; integration test passes" is.

Observable = something another agent can verify by reading the code or running a command, without asking the author.

---

## Active → completed lifecycle

When all tasks are checked:

1. Update `Status:` from `active` to `completed`
2. Add `**Completed:** <date>` field
3. Move file from `docs/exec-plans/active/` to `docs/exec-plans/completed/`
4. Add a one-line summary at the top if the outcome differed from the goal

**Do not rewrite** completed plans when code later changes. They are historical record. See `freshness-refactor.md` for how to annotate instead.

---

## Tech debt entries

Debt that surfaces during a plan (but isn't worth fixing now) goes in `docs/exec-plans/tech-debt-tracker.md`. One flat file, one entry per item. Agents grep this — keep it scannable.

**Entry format:**

```markdown
## <short title>

- **Where:** `src/auth/jwt.ts:42-58`
- **Symptom:** Token refresh uses setTimeout; not resilient to clock drift or process restart.
- **Why deferred:** Fixing requires a job queue (not yet introduced).
- **Trigger to fix:** When we add a background job runner, migrate this first.
- **Created:** 2026-04-14
```

Required fields:
- **Where** — exact file and line range. Debt without a location is a rumor.
- **Symptom** — what's wrong, in behavioral terms (not "code smells")
- **Why deferred** — so future-you doesn't try to "helpfully" fix it and hit the same wall
- **Trigger to fix** — the event that makes it worth revisiting. Without this, debt accumulates forever.

Line-level quirks also belong here: "Bug workaround at `path/to/file.ts:117` — library X returns `null` instead of `undefined` on empty result; do not 'fix' this check."

---

## When a plan spans multiple exec plans

If work is big enough that one plan feels wrong, split by **deliverable**, not by time. Each sub-plan gets its own file in `active/`, and a parent plan references them:

```markdown
## Tasks
- [ ] See `auth-tokens.md` — JWT + refresh
- [ ] See `auth-2fa.md` — TOTP
- [ ] See `auth-hardening.md` — rate limits, lockout
```

This keeps each file's task list small enough to stay committable-sized.

---

## Self-review before declaring the plan ready

Before handing the plan to anyone (human or agent), walk this checklist. Each item is a failure mode observed in real plans.

- [ ] **Spec referenced or explicitly skipped.** Background cites a design doc / product spec, or states "no design doc; mechanical change."
- [ ] **Every task has an observable Done when.** "Implement X" is not observable; "endpoint returns 201 on valid input, 409 on duplicate, integration test covers both" is.
- [ ] **No banned phrasings.** Re-scan the Tasks list against the table above. Rewrite any hits.
- [ ] **Files: hint on every task.** A task with no expected touch points forces the next agent to re-discover the architecture.
- [ ] **Out of scope is non-empty.** Empty Out-of-scope means scope creep is unchecked. Even on small plans, name 1–2 things you are deliberately not doing.
- [ ] **Tasks cover the stated Goal.** Read the Goal sentence, then read the Tasks list. If the tasks complete, will the Goal sentence be true? If not, you're missing tasks (or the Goal is wrong).
- [ ] **No task depends on a future task that isn't in the plan.** If task 5 needs an "auth library decision" that isn't an earlier task or a referenced ADR, the plan has a hole.
- [ ] **Decisions log seeded.** At least one entry pointing to the spec(s) — even if it's just "2026-04-14: See `docs/design-docs/<topic>.md` for shape rationale."

This pass takes 2–3 minutes and catches the failures that turn a "good-looking" plan into one that stalls on first contact with another agent.
