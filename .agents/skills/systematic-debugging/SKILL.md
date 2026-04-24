---
name: systematic-debugging
description: Root-cause-first debugging for bugs, failing tests, flaky behavior, broken builds, and integrations. Invoke whenever something is failing or behaving unexpectedly. Do not patch symptoms, stack fixes, or guess under time pressure.
---

# Systematic Debugging

Random fixes waste time and create new bugs. A symptom patch that happens to silence the error is not a diagnosis.

Core rule: find the root cause before attempting fixes.

---

## The iron law

`No fixes without root-cause investigation first.`

If you have not reproduced the issue and gathered evidence, you are not ready to propose a fix.

---

## When to use this

Use for:

- failing tests
- runtime bugs
- build or CI failures
- integration breakages
- flaky or timing-sensitive behavior
- "it worked before" regressions

Use it especially when:

- the fix looks "obvious"
- you're under time pressure
- two or more fixes already failed
- the issue crosses component boundaries

---

## Phase 1 - Reproduce and gather evidence

Before touching code:

1. Read the actual error completely.
2. Reproduce the failure consistently, or say that you cannot yet reproduce it.
3. Check what changed recently: code, config, dependencies, environment.
4. Capture the exact command, inputs, and environment that trigger the issue.

If the system has multiple layers, instrument the boundaries first:

- request in
- data passed between components
- config and env propagation
- output or failure at each layer

The goal is not "more logs". The goal is evidence that shows where the system stops behaving as expected.

---

## Phase 2 - Isolate the failing boundary

Trace the issue backward from the symptom:

- where is the bad value or bad state observed?
- who called that code?
- where did the wrong input originate?
- what boundary should have validated, transformed, or blocked it?

Fix at the source, not where the crash finally appears.

If the issue spans multiple services, jobs, or scripts, narrow it to the first boundary that is demonstrably wrong. Do not keep the entire system as the unit of debugging.

---

## Phase 3 - Compare against something known-good

Before inventing a fix:

- find a similar working path in the same codebase
- compare the failing path to the expected pattern
- read reference implementations fully if this is a known library/framework pattern
- list the differences, even the ones that seem too small to matter

Debugging gets easier when you move from "why is this broken?" to "what is different from the version that works?"

---

## Phase 4 - Form one hypothesis and test it minimally

State the hypothesis explicitly:

`I think X is the root cause because Y.`

Then test it with the smallest change or experiment that can falsify it.

Rules:

- one hypothesis at a time
- one variable at a time
- no bundled fixes
- no "while I'm here" refactors

If the experiment fails, do not stack another fix on top. Return to evidence and form a new hypothesis.

---

## Phase 5 - Create a failing repro before the final fix

Before the production fix lands, capture the failure in a durable form:

- automated test if possible
- one-off repro script if no test harness exists
- documented manual repro if the system genuinely cannot be automated yet

The repro should prove two things:

- the bug exists before the fix
- the chosen fix actually closes it

If you cannot capture the failure, say so explicitly and explain what evidence you are relying on instead.

---

## Phase 6 - Implement one fix and verify

The fix should address the identified root cause only.

Then verify:

- the repro now passes
- adjacent tests or checks still pass
- the original user-visible symptom is gone

If verification cannot be run, stop short of claiming the issue is fixed and hand off to `quality-gates` style reporting.

---

## Stop conditions

Stop and re-evaluate when:

- you are proposing fixes before reproducing
- you have tried 2+ fixes and each revealed a new symptom
- the issue keeps moving across shared state or architectural boundaries
- the "fix" requires broad refactoring just to make the symptom disappear

At 3 failed fix attempts, stop treating it as a local bug. Question the architecture or underlying pattern with the user.

---

## Red flags

If you catch yourself thinking:

- "just try this"
- "quick fix for now"
- "let's change two things and rerun"
- "I'll add the test after confirming"
- "I don't fully understand it, but this might work"

That is the signal to go back to Phase 1.

---

## What this bundle is not

- Not a replacement for `planning-first` - debugging is not feature planning
- Not a replacement for `quality-gates` - root-cause work still needs fresh verification before completion claims
- Not a replacement for `tdd` - TDD writes tests before implementation; this bundle creates a repro before a bug fix

This bundle exists to stop guess-and-check thrashing and force evidence-led debugging.
