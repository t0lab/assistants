#!/usr/bin/env bash
# commit-msg git hook: enforce Conventional Commits format on the commit message.
# Sits in .githooks/commit-msg.d/ — the dispatcher at .githooks/commit-msg runs it alongside other bundles' contributions.
#
# Rejects any commit whose subject line does not match:
#   <type>[optional scope][!]: <description>
# where <type> ∈ feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert
#
# Exempts merge commits and revert auto-messages.

set -e

MSG_FILE="$1"
[ -f "$MSG_FILE" ] || exit 0

SUBJECT=$(head -n 1 "$MSG_FILE")

# Skip comments, merge commits, fixup/squash autos, and empty subjects
case "$SUBJECT" in
  ''|'#'*|'Merge '*|'Revert '*|'fixup! '*|'squash! '*|'amend! '*)
    exit 0
    ;;
esac

# Type regex — bracketed scope optional, '!' for breaking change optional
TYPE_RE='^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-z0-9._/-]+\))?!?: .+'

if ! printf '%s' "$SUBJECT" | grep -qE "$TYPE_RE"; then
  cat >&2 <<EOF
✗ Commit message does not follow Conventional Commits.

  got: $SUBJECT

  expected: <type>(<optional-scope>)[!]: <description>
    type ∈ feat | fix | docs | style | refactor | perf | test | build | ci | chore | revert
    use '!' or a 'BREAKING CHANGE:' footer for breaking changes

  examples:
    feat(parser): add support for scoped packages
    fix: handle empty input in tokenizer
    refactor(core)!: drop Node 18 support

  Invoke the 'git-conventional' skill if you need help composing the message.
EOF
  exit 1
fi

# Subject length sanity — warn at 72, block at 100
LEN=${#SUBJECT}
if [ "$LEN" -gt 100 ]; then
  echo "✗ Commit subject is ${LEN} chars (limit 100). Move detail into the body." >&2
  exit 1
elif [ "$LEN" -gt 72 ]; then
  echo "⚠ Commit subject is ${LEN} chars (recommended ≤72). Consider moving detail into the body." >&2
fi

exit 0
