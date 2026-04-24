---
name: git-conventional
description: Conventional Commits format guide — invoke before any git commit, when writing a commit message, or when the user asks how to format a commit. Use this proactively whenever you're about to run git commit, suggest a commit message, or help with git history. Also covers semantic versioning implications (feat = minor bump, fix = patch bump, feat! = major bump).
---

# Conventional Commits

## Format

```
<type>[(<scope>)][!]: <description>

[body]

[footer(s)]
```

- **Description**: imperative mood, present tense, ≤72 chars, no period at end
- **Body**: explain *what* and *why*, not how — blank line after subject
- **Breaking change**: append `!` to type (`feat!:`) or add footer `BREAKING CHANGE: <description>`

---

## Types

| Type | When to use |
|------|-------------|
| `feat` | New feature visible to users |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `refactor` | Restructure without feature/fix |
| `test` | Add or update tests |
| `chore` | Maintenance, deps, tooling |
| `build` | Build system or dependency changes |
| `ci` | CI/CD config |
| `perf` | Performance improvement |
| `style` | Formatting only (no logic change) |
| `revert` | Revert a previous commit |

---

## Semver implication

Conventional Commits maps directly to semantic versioning:

| Commit | Version bump |
|--------|-------------|
| `fix:` | Patch (0.0.x) |
| `feat:` | Minor (0.x.0) |
| `feat!:` or `BREAKING CHANGE:` | Major (x.0.0) |
| `chore:`, `docs:`, `style:`, `test:` | No release |

---

## Examples

**Simple:**
```
feat(cli): add zone-based tech stack selector
fix(registry): resolve manifest path on Windows
```

**With body (explain why):**
```
refactor(engine): extract token budget into separate module

Token budget logic was growing inside applyModules() and made
it hard to test independently. No behavior change.
```

**Breaking change:**
```
feat!(cli): replace --preset flag with interactive wizard

BREAKING CHANGE: --preset flag is removed. Use `harness-kit init`
for the interactive flow or `harness-kit add <preset>` directly.
```

**With issue references:**
```
fix(wizard): skip tsconfig detection when no src/ dir found

Closes #42
Refs #38
```

**Chore / maintenance:**
```
chore: bump tsup to v8
build: add @types/node to devDependencies
ci: add pnpm cache to GitHub Actions workflow
```

---

## Rules

- One logical change per commit — keep commits atomic
- Reference issues in footer: `Closes #123` or `Refs #456`
- Never add `Co-Authored-By` lines
- Never use `--no-verify` — fix the hook failure instead
- Hook fails → fix the issue, create a **new** commit (never `--amend` a published commit)

---

## Scope conventions

Scope is optional but recommended for larger codebases. Use the module, package, or area of the code:

```
feat(auth): add OAuth2 refresh token support
fix(api/users): handle missing profile picture gracefully
chore(deps): upgrade vitest to v3
```

Keep scopes short (1-2 words), consistent, and lowercase.
