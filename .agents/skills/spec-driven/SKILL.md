---
name: spec-driven
description: Spec before plan for non-trivial work. Invoke when the user asks for a feature, refactor, workflow change, API change, or any multi-step task where the why, scope, or acceptance criteria could drift. Do not let implementation become the de facto spec.
---

# Spec Driven

A plan tells you how to build. A spec tells you what you are building, why it exists, and what is out of scope. If the change is non-trivial and no spec exists, the agent is guessing.

Use this skill to make the spec the source of truth before planning and implementation.

---

## When a spec is required

Write or update a spec when any of these are true:

- user-visible behavior will change
- API shape, CLI behavior, or data contracts will change
- multiple files or phases are involved
- there are explicit non-goals or scope boundaries to preserve
- reasonable engineers could disagree on what "done" means
- you'd be annoyed if the implementation set policy by accident

Skip the full spec only for mechanical, single-commit changes with obvious scope. If you skip it, say so explicitly.

---

## Step 1 - Choose the spec type

Choose the smallest document that can hold the decision:

- `docs/product-specs/<feature>.md` for user-facing scope, goals, non-goals, and success criteria
- `docs/design-docs/<topic>.md` for technical shape, invariants, and rejected alternatives
- both, if the feature has product intent and a non-trivial technical decision

Rule of thumb:

- "What problem are we solving and for whom?" -> product spec
- "Why this architecture and not another?" -> design doc

If the repo has no `docs/` structure yet, create the minimum path you need rather than keeping the spec in chat.

---

## Step 2 - Write the minimum viable spec

The spec must answer the questions implementation will otherwise answer by accident.

### Product spec must cover

- problem
- goals
- non-goals
- solution sketch
- success metrics or acceptance criteria
- open questions

### Design spec must cover

- context / forcing constraint
- decision
- rejected alternatives with reasons
- consequences
- invariants future code must respect
- revisit signal

Keep it lean. A good spec is decisive, not long.

---

## Step 3 - Make it executable

A spec is usable only if an agent can turn it into a plan without guessing.

Check for:

- concrete scope boundaries, not "improve UX" or "support auth"
- observable acceptance criteria
- explicit non-goals
- named users, callers, or systems affected
- unresolved questions separated from settled decisions

Bad spec signals:

- implementation detail fills the page but user-visible behavior is unclear
- "TBD", "etc.", "and more"
- hidden policy decisions inside code examples
- no statement of what must not change

If a reviewer could interpret the spec in two materially different ways, it is not ready.

---

## Step 4 - Gate planning on the spec

Do not write the execution plan first.

Sequence:

1. explore the code and current docs
2. write or update the spec
3. get user alignment on the spec if the change is non-trivial
4. write the execution plan that references the spec
5. implement

The plan should cite the spec path directly. The plan is allowed to decompose work; it is not allowed to redefine product scope or architecture silently.

---

## Step 5 - Keep spec and code aligned

If implementation reveals that the chosen shape is wrong:

- stop
- update the spec or design doc
- note the change in the plan
- then continue

Do not let code diverge and promise to "clean up docs later". That turns the spec into fiction.

---

## What this bundle is not

- Not a replacement for `planning-first` - that bundle governs exploration, questions, options, and approval flow
- Not a replacement for `docs-as-code` - that bundle defines the broader documentation system and doc taxonomy
- Not a replacement for `quality-gates` - a spec can be correct and the implementation can still be broken

This bundle exists to prevent one specific failure mode: implementation becoming the first precise statement of scope.
