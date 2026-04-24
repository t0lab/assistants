---
name: planning-first
description: Brainstorm → spec → approval → plan → execute. Invoke before any multi-step, multi-file, or architecturally-novel task, and whenever the user says "implement X", "build Y", "add a feature", "refactor Z". Also invoke when executing an already-approved plan — the execution phase has its own discipline (critique before exec, verify after each task, stop on failure).
---

# Planning First

Write the plan before the code. Most wasted work comes from implementing the wrong thing, or the right thing in a way that won't survive review — both are planning failures, not coding failures.

This skill has **two modes**, gated by task size:

- **Light** — single-file change, obvious shape, ≤30 minutes of work. Skip to implementation; no spec, no approval gate.
- **Full** — anything else. Follow the 5 phases below.

When in doubt, go Full. The cost of an unnecessary plan is minutes; the cost of a wrong implementation is hours.

---

## Phase 1 — Explore first

Do **not** ask questions or propose approaches before reading the code. Planning against the wrong mental model produces a perfect plan that solves the wrong problem.

Before anything else:

- Read the relevant files (Grep to locate, Read with offset/limit for targeted sections)
- Scan recent commits in the area (`git log -- <path>`) for context on recent decisions
- Skim `docs/` and `CLAUDE.md` / `AGENTS.md` for existing conventions
- Check if a similar feature already exists — reuse > invent

Only then start asking questions.

---

## Phase 2 — Clarify, one question at a time

**One question per message.** Don't batch. Don't bundle a question with a summary. Don't ask an open-ended question when a multiple-choice works.

Ask about, in priority order:
1. **Purpose** — what problem does this solve, who's the user, what's the success criterion?
2. **Constraints** — performance budgets, API compatibility, security, deadlines
3. **Scope boundaries** — explicitly what's in and what's out

If the task spans multiple independent subsystems, **stop and decompose first** — propose splitting it into separate planning passes. A single plan that crosses unrelated subsystems is almost always too coarse.

---

## Phase 3 — Propose 2–3 approaches with trade-offs

Don't lock in the first idea. Put 2–3 viable approaches on the table with honest trade-offs, and **lead with your recommendation and why**.

Format:

> **Recommendation: Approach A** — <one-sentence reason>
>
> - **A. <name>** — how it works, pros, cons
> - **B. <name>** — how it works, pros, cons
> - **C. <name>** (optional) — how it works, pros, cons

Let the user pick or redirect. Do not write the plan until an approach is chosen.

---

## Phase 4 — Write the plan

A plan is **immediately actionable**. No placeholders, no hand-waving.

Required sections:

1. **Goal** — one sentence, verifiable
2. **Context / architecture** — 2–3 sentences, where this sits in the system
3. **Requirements / success criteria** — bulleted, each independently checkable
4. **Tasks, grouped into phases** — each phase independently mergeable
5. **Per task**: exact file paths, concrete code sketches (not "add validation"), commands with expected output, dependencies on prior tasks, risks
6. **Testing strategy** — per phase
7. **Risks & mitigations**

Red flags to scrub before calling it done:

- "TBD", "TODO", "add X", "handle edge cases", "similar to Task N"
- Forward references to symbols no earlier task defines
- Tasks that span multiple unrelated files
- Signatures that don't match between tasks

For larger work, save the plan to `docs/exec-plans/active/<name>.md` so it survives the session.

---

## Phase 5 — Gate, then execute

**Hard gate: do not write implementation code, scaffold files, run installers, or touch the filesystem outside the plan doc until the user approves the plan.** This applies to "simple" projects too — simple projects hide the unexamined assumption.

When presenting the plan, ask for explicit approval. Don't treat silence or "sure" as a green light if the plan is non-trivial; confirm.

### 5a — Critique the plan before executing

Before the first line of implementation code — **even for plans you just wrote yourself** — re-read the plan with fresh eyes and flag:

- Gaps, contradictions, or ambiguous instructions
- Tasks whose success criteria are not independently verifiable
- Forward references to symbols no earlier task defines
- Commands whose expected output isn't specified

Escalate every concern before starting. Do **not** self-resolve ambiguity by guessing the user's intent — ask. A plan that survived approval but fails this critique means approval was premature; surface it.

### 5b — Execute phase by phase

- **Never start implementation on `main` / `master` without explicit user consent.** If you're on the wrong branch, stop and ask.
- Work through tasks in the order the plan specifies. Don't reorder "because it's faster"; the plan chose the order for a reason.
- **After every task, run the verification the plan names** (test, typecheck, lint, manual command — whatever the plan wrote). No verification listed is a plan bug; stop and fix the plan.
- **Stop-on-failure.** A failing test, broken typecheck, or unexpected output is a blocker, not a speed bump. Do not force through. Do not silently patch around it. Report and escalate.
- At each phase boundary, re-open the plan — check off what's done, note what changed.

### 5c — When reality diverges from the plan

If implementation reveals the plan is wrong (missing case, wrong API shape, unforeseen dependency):

1. **Stop coding.**
2. **Update the plan first** — amend the affected tasks, flag the divergence explicitly.
3. Re-confirm with the user if the divergence changes scope, success criteria, or any settled decision.
4. Only then resume.

Don't let code and plan drift. A plan that stops matching the code is worse than no plan — it actively misleads the next reader (including future you).

---

## Anti-patterns

| Anti-pattern | Why it fails |
|--------------|--------------|
| "This is too simple to plan" | The assumptions you didn't examine are the ones that bite |
| Planning before reading the code | Plan references wrong files, wrong patterns, non-existent helpers |
| Batched clarifying questions | User answers one, ignores the others, plan proceeds on half-context |
| Single-approach plan | First idea locked in without seeing alternatives |
| Placeholder tasks | "add error handling" — no test, no diff, no way to verify |
| Self-approval | Exiting the gate without explicit user signoff |
| Skipping 5a critique | "I just wrote the plan, it's fine" — approval ≠ correctness; fresh-eye review catches gaps |
| Forcing through a failing verification | Turns a 1-task blocker into a 3-task debugging mess; escalate instead |
| Silent divergence | Code veers from plan, plan isn't updated — subsequent tasks compound on a wrong premise |
| Implementing on main | Skipping branch setup to "save time" — blocks rollback, pollutes history |
| Over-planning | 200-line plan for a 5-line fix — wastes a session's attention budget |
