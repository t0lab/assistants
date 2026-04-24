#!/usr/bin/env bash
# Tech-stack-aware pre-commit gate. Each check self-detects via project files —
# JS only runs when package.json exists, Go only when go.mod exists, etc.
# Sits in .githooks/pre-commit.d/ — the dispatcher at .githooks/pre-commit runs it alongside other bundles' contributions.

set -e

STAGED=$(git diff --cached --name-only --diff-filter=ACMR)
[ -z "$STAGED" ] && exit 0

# ── Always: conflict markers in staged files ─────────────────────────────────
BAD=""
while IFS= read -r f; do
  [ -f "$f" ] || continue
  if git show ":$f" 2>/dev/null | grep -qE '^(<<<<<<< |>>>>>>> |=======$)'; then
    BAD="$BAD\n  $f"
  fi
done <<< "$STAGED"
if [ -n "$BAD" ]; then
  echo "✗ Unresolved conflict markers:" >&2
  printf "%b\n" "$BAD" >&2
  exit 1
fi

# ── Always: obvious secrets ──────────────────────────────────────────────────
SECRET_RE='(AKIA[0-9A-Z]{16}|-----BEGIN (RSA|OPENSSH|DSA|EC|PGP) PRIVATE KEY-----|xox[pbar]-[0-9A-Za-z-]{10,}|gh[pousr]_[0-9A-Za-z]{36,}|sk-ant-[0-9A-Za-z_-]{40,}|sk-[A-Za-z0-9]{32,}|sk_live_[0-9a-zA-Z]{24,}|AIza[0-9A-Za-z_-]{35})'
HITS=""
while IFS= read -r f; do
  [ -f "$f" ] || continue
  case "$f" in *.lock|*.lockb|package-lock.json|*.min.js|*.map) continue ;; esac
  if git show ":$f" 2>/dev/null | grep -nE "$SECRET_RE" >/dev/null; then
    HITS="$HITS\n  $f"
  fi
done <<< "$STAGED"
if [ -n "$HITS" ]; then
  echo "✗ Possible secrets staged:" >&2
  printf "%b\n" "$HITS" >&2
  echo "  Redact and re-stage. False positive? git commit --no-verify (rare)." >&2
  exit 1
fi

# ── Node.js: only when package.json + JS/TS changes ──────────────────────────
if [ -f "package.json" ] && echo "$STAGED" | grep -qE '\.(js|jsx|ts|tsx|mjs|cjs)$'; then
  PM="npm"
  [ -f "pnpm-lock.yaml" ] && PM="pnpm"
  [ -f "yarn.lock" ] && PM="yarn"
  { [ -f "bun.lockb" ] || [ -f "bun.lock" ]; } && PM="bun"
  has() { node -e "const s=require('./package.json').scripts||{};process.exit(s['$1']?0:1)" 2>/dev/null; }
  for target in lint typecheck; do
    if has "$target"; then
      echo "→ $PM run $target"
      $PM run "$target"
    fi
  done
fi

# ── Python: ruff + mypy when configured ──────────────────────────────────────
if { [ -f "pyproject.toml" ] || [ -f "requirements.txt" ] || [ -f "setup.py" ]; } \
   && PY_STAGED=$(echo "$STAGED" | grep -E '\.py$') && [ -n "$PY_STAGED" ]; then
  if command -v ruff >/dev/null 2>&1; then
    echo "→ ruff check"
    ruff check $PY_STAGED
  fi
  if grep -q "\[tool.mypy\]" pyproject.toml 2>/dev/null && command -v mypy >/dev/null 2>&1; then
    echo "→ mypy"
    mypy $PY_STAGED
  fi
fi

# ── Go: gofmt + go vet ───────────────────────────────────────────────────────
if [ -f "go.mod" ] && GO_STAGED=$(echo "$STAGED" | grep -E '\.go$') && [ -n "$GO_STAGED" ]; then
  if command -v gofmt >/dev/null 2>&1; then
    UNFMT=$(gofmt -l $GO_STAGED)
    if [ -n "$UNFMT" ]; then
      echo "✗ gofmt: unformatted:" >&2
      echo "$UNFMT" >&2
      echo "  Run: gofmt -w ." >&2
      exit 1
    fi
  fi
  if command -v go >/dev/null 2>&1; then
    echo "→ go vet ./..."
    go vet ./...
  fi
fi

# ── Rust: cargo fmt + clippy ─────────────────────────────────────────────────
if [ -f "Cargo.toml" ] && echo "$STAGED" | grep -qE '\.rs$' && command -v cargo >/dev/null 2>&1; then
  echo "→ cargo fmt --check"
  cargo fmt --check
  echo "→ cargo clippy -- -D warnings"
  cargo clippy --quiet -- -D warnings
fi

exit 0
