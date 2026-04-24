---
name: quality-gates
description: Fresh verification before any completion claim. Invoke after implementation, after bug fixes, before saying "done", "fixed", "ready", or "safe to merge", and before commit/PR handoff. Do not infer success from code inspection or an old test run.
---

# Quality Gates

Completion is a claim about reality, not a feeling about the diff. If you have not run the command that proves the claim in this session, you do not have evidence yet.

This skill answers one question: what fresh verification is required before you can honestly say the work is done?

---

## The Rule

`No completion claims without fresh verification evidence.`

That applies to all equivalents:

- "done"
- "fixed"
- "ready"
- "should work"
- "safe to merge"
- "all good"

If verification cannot be run, say that directly and state the residual risk. Never blur "not verified" into "complete".

---

## Step 1 - Define the claim

State the exact claim you are about to make, then choose the evidence that proves it:

| Claim | Minimum evidence |
|------|-------------------|
| Bug fixed | Reproduction or regression test now passes |
| Feature works | Tests for new behavior pass |
| Refactor is safe | Existing tests for touched surface still pass |
| Ready to commit / PR | Repo-appropriate verification suite for touched files passes |
| Build is healthy | Build command exits 0 |
| Lint is clean | Lint command reports 0 errors |
| Types are valid | Typecheck / compile step exits 0 |

Do not substitute one proof for another. Lint is not build. Build is not tests. Old output is not fresh evidence.

---

## Step 2 - Choose the verification set

Start from the changed surface, not from habit.

### Always inspect first

- Read the diff
- Identify which files and layers changed
- Detect the project's canonical commands before inventing your own

Prefer project-owned scripts and task runners:

- Node: `package.json` scripts via `pnpm|npm|yarn|bun run`
- Python: `pytest`, `ruff`, `mypy`, project wrappers like `tox` or `just`
- Go: `go test ./...`, `go vet ./...`, `gofmt -l`
- Rust: `cargo test`, `cargo fmt --check`, `cargo clippy -- -D warnings`

### Escalate verification by change type

| Change type | Usually required |
|------------|------------------|
| Logic / bug fix | Targeted tests proving the changed behavior |
| Shared library / public API / schema | Targeted tests + broader suite + typecheck/build |
| TS/JS source | Tests + lint + typecheck if scripts exist |
| UI flow | Relevant automated test, or browser/manual verification if no automation exists |
| Build / config / dependency changes | Build/install command that exercises the changed path |
| Only docs / comments | Link check or docs build if present; otherwise explain why no code verification is needed |

Use the smallest set that honestly proves the claim. High-risk or cross-cutting changes need broader verification, not clever wording.

---

## Step 3 - Run commands fresh

Run the full commands now. No partial logs, no stale output, no "it passed earlier".

Good pattern:

1. Targeted verification for the exact change
2. Project-level gates for the touched surface
3. Optional broader sweep if the change is risky

Example sequence:

```bash
pnpm test -- --runInBand src/foo/bar.test.ts
pnpm lint
pnpm typecheck
pnpm build
```

If the repo only exposes one canonical command such as `make verify`, `just check`, or `npm test`, use that instead of reconstructing a custom pipeline.

---

## Step 4 - Read the output, don't pattern-match it

Check:

- exit code
- failure count
- whether the command actually covered the changed area
- whether warnings imply residual risk

Common failure modes:

- command passed, but not the tests that exercise the changed code
- targeted test passed, but typecheck/build was skipped after touching interfaces
- command failed and the failure was omitted from the summary
- output was from before the last edit

If anything fails, report the real state:

- what failed
- whether you fixed it
- what remains unverified

---

## Step 5 - Report with evidence

Completion reports should name the proof, not just the conclusion.

Good:

- "Verified with `pnpm test -- foo.test.ts` and `pnpm typecheck`; both passed after the last edit."
- "I fixed the bug and confirmed the regression with `pytest tests/test_login.py -k expired_token`."
- "I have not run the build yet, so I cannot claim this is ready to merge."

Bad:

- "Done."
- "Should pass now."
- "Looks good to me."
- "I think this is fixed."

---

## Minimal exit checklist

Before any completion claim, confirm:

- I know exactly what claim I am making
- I ran the command that proves that claim after the last code change
- The command covered the changed surface
- I read the actual output
- My summary distinguishes verified facts from remaining risk

Miss one box and the gate has not passed.
