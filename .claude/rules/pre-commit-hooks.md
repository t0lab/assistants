# Pre-Commit Hooks

A pre-commit gate runs before every `git commit`: conflict-marker check, secret scan, and tech-stack-appropriate lint/typecheck/test (Node/Python/Go/Rust auto-detected).

- If the hook fails, **fix the underlying issue** — re-stage and create a new commit. Do not `--amend` a failed commit (the commit never happened) and do not use `--no-verify` to bypass unless the user explicitly asks.
- The dispatcher at `.githooks/pre-commit` runs every `*.sh` in `.githooks/pre-commit.d/` in sorted order — each bundle that ships a pre-commit check drops its script there, so multiple bundles compose cleanly.
- To add a project-specific check, drop an executable `*.sh` into `.githooks/pre-commit.d/`.
- Activate once per clone: `git config core.hooksPath .githooks` (or `npx harness-kit activate`).
