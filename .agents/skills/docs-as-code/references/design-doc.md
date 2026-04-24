# Design Docs & ADRs

Design docs (also called ADRs — Architecture Decision Records) capture **why** the code is the way it is. Of all documentation, these pay back the most over time: code shows *what*, git shows *when*, but only design docs show *why*.

The baseline benchmark showed agents usually know *where* an ADR lives. The skill's value here is enforcing a **structured Consequences section** — this is the part that's consistently underbaked without guidance.

---

## ADR template

Copy this into `docs/design-docs/<kebab-case-topic>.md`:

```markdown
# <Decision title — active voice, e.g., "Use Postgres for session storage">

**Status:** accepted
**Date:** 2026-04-14
**Deciders:** <names / roles>

## Context
<What problem forced this decision? What constraints shaped it?
2–5 sentences. Enough that a reader in 2 years gets it without asking anyone.>

## Decision
<What we chose. One paragraph. Specific.>

## Alternatives considered
- **<Option A>** — rejected because <specific reason>.
- **<Option B>** — rejected because <specific reason>.
- **<Option C>** — seriously considered; would revisit if <trigger>.

## Consequences

**Better:**
- <What gets easier or safer>
- <What capability we gain>

**Worse:**
- <What gets harder, slower, or more constrained>
- <What we give up>

**Must now be true:**
- <Invariants this decision creates — e.g., "All session reads go through SessionStore; never query the table directly">
- <Rules future code must respect>

## Revisit if
<The specific signal that would make us reopen this decision.>
```

Each section earns its place:
- **Context** — so the decision doesn't look arbitrary in retrospect
- **Alternatives considered** — so the same debate doesn't repeat in 6 months
- **Consequences (Better / Worse / Must now be true)** — the three-way split forces honest accounting. Pure "Better" lists are propaganda.
- **Revisit if** — turns the doc from fossil into living reference

---

## The Consequences breakdown (most important)

Most ADRs fail here. They list benefits and call it done. The three-way split forces the harder thinking:

**Better** — capabilities gained. Specific. Not "more flexibility" (too vague) — instead "can swap storage backends by changing one interface implementation."

**Worse** — costs accepted. Be honest. "Adds 80ms to cold start" is useful. "Some tradeoffs" is useless. If you can't name a downside, you haven't thought hard enough — every real decision has them.

**Must now be true** — invariants future code must preserve. This is often the most valuable section for agents. Example: "All session tokens must go through `SessionStore.create()` — direct DB inserts bypass the audit log and will break compliance reporting." An agent reading this knows exactly which guardrail not to cross.

---

## Capturing rejected alternatives

Rejected options are a gift to future readers. They prevent the same debate from happening again and signal what we've already considered.

**Weak:**
> We considered other databases but chose Postgres.

**Strong:**
> - **Redis** — rejected. Needed durable storage with relational queries; sessions link to users, teams, audit logs. Redis would force denormalization we'd regret.
> - **DynamoDB** — rejected. Ops team doesn't operate Dynamo; on-call would be a liability. Would revisit if we moved to AWS-managed infra end-to-end.
> - **SQLite** — seriously considered for simplicity. Rejected because multi-region writes are on the roadmap for 2026 Q3.

Specific rejections with specific reasons. Each line should teach the reader something about the constraints.

---

## When to write an ADR

Write one when **any of these are true**:
- The decision creates an invariant other code must respect
- Reasonable engineers would disagree on the choice
- You'd be annoyed if someone undid it without talking to you
- You debated it for more than an hour (with yourself or others)

Don't write one for:
- Obvious choices with no real alternatives
- Pure implementation details (which sort algorithm to use)
- Things already documented in library docs

If in doubt: write it. Under-documenting is far more costly than over-documenting.

---

## Status lifecycle

- `proposed` — under discussion, not yet acted on
- `accepted` — in effect, code reflects it
- `superseded by <filename>` — replaced; keep the file for history, add link to successor
- `deprecated` — no longer in effect but no successor; explain why in a note

Never delete an ADR. Superseded docs explain why the *current* decision was made.

---

## Product specs (separate from ADRs)

Product specs live in `docs/product-specs/<feature>.md`. They answer "what is this feature and why does it exist from a user/business angle?" — not "what technical choice did we make."

**Product spec template:**

```markdown
# <Feature name>

**Status:** <planned | in-progress | shipped>
**Owner:** <PM or tech lead>
**Last updated:** 2026-04-14

## Problem
<Who hurts today and how? Evidence if available.>

## Goals
- <Specific, measurable where possible>

## Non-goals
- <Explicit exclusions — prevents scope creep>

## Solution sketch
<High-level shape. Not implementation detail.>

## Success metrics
<How we'll know this worked.>

## Open questions
<Unresolved items that block or could change the approach.>
```

Product specs and design docs often cross-reference each other. A feature (product spec) may spawn multiple technical decisions (ADRs). Keep them separate — they have different authors, audiences, and lifecycles.

---

## Self-review before declaring the doc ready

Walk this list before saving. Each item is a failure mode that recurs in real ADRs.

- [ ] **Status and Date present.** Missing either makes the doc unjudgeable in a year.
- [ ] **Context names the forcing constraint.** Not "we need session storage" — *why now, what bounded the choice*.
- [ ] **Decision is one specific paragraph.** If it spans three pages or three options, you haven't decided yet.
- [ ] **At least one rejected alternative with a specific reason.** "We considered others" is not an alternative; "Redis — rejected because we need relational queries against sessions" is.
- [ ] **Consequences split into Better / Worse / Must-now-be-true.** A pure-Better list is propaganda; if you can't name a downside, you haven't thought hard enough.
- [ ] **"Must now be true" names invariants in code terms.** "All session reads go through `SessionStore`; never query the table directly" — concrete enough that a future agent can grep for violations.
- [ ] **Revisit-if has a specific signal.** "If requirements change" is not a signal; "If multi-region writes land on the roadmap" is.
- [ ] **No undefined acronyms or unlinked references.** Every named system, file, or external concept has a link or a one-line gloss.
- [ ] **If this supersedes another ADR**, the old one is updated to `superseded by <this-file>.md`. Bidirectional link or it gets lost.
