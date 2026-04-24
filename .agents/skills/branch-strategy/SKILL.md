---
name: branch-strategy
description: Branch naming and PR sizing conventions — invoke before creating a branch, opening a PR, or when a diff exceeds 400 lines. Do NOT trigger on read-only questions about current branch/PR state (e.g. "what branch am I on", "link to the PR").
---

# Branch Strategy

## Branch Naming

Pattern: `<type>/<short-description>`

| Type | When |
|------|------|
| `feature/` | New functionality |
| `fix/` | Bug fix |
| `chore/` | Maintenance, deps, config |
| `docs/` | Documentation only |
| `refactor/` | Restructure, no behavior change |
| `test/` | Adding or updating tests |

Use kebab-case, keep it short (2-4 words), no nested slashes.

**Examples:**
```
feature/add-user-auth
fix/login-redirect
chore/bump-tsup-v8
docs/update-readme
refactor/extract-token-budget
test/artifact-installer-rule
```

**Not:**
```
feature/addUserAuth          ← camelCase
fix/fix-the-login-bug        ← redundant "fix" in description
feature/auth/oauth/flow      ← nested slashes
my-branch                    ← missing type prefix
```

## PR Size

Target **< 400 lines changed** per PR. Small PRs get reviewed faster, catch bugs earlier, and are easier to revert.

When a diff exceeds 400 lines, suggest splitting:
- Separate refactoring from new features
- Extract type/interface changes into a prep PR
- Split by domain boundary (API vs UI vs DB)

Exceptions that don't need splitting: generated files, migrations, large atomic refactors where partial application would break the build.

## Protected Branches

- `main` / `master` — never commit directly, always use a PR
- Delete feature branches after merge
