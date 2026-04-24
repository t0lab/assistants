#!/usr/bin/env bash
# pre-commit git hook: block commits that contain unresolved conflict markers in .claude/memory/.
# Conflicts here mean two devs' agents wrote overlapping memory — resolve via `memory-merge` skill first.

set -e

MEMORY_DIR=".claude/memory"

if [ ! -d "$MEMORY_DIR" ]; then
  exit 0
fi

CONFLICTED=$(grep -rlE '^(<<<<<<< |>>>>>>> |=======$)' "$MEMORY_DIR" 2>/dev/null || true)

if [ -n "$CONFLICTED" ]; then
  echo "✗ Unresolved memory conflicts:" >&2
  echo "$CONFLICTED" >&2
  echo "" >&2
  echo "Invoke the 'memory-merge' skill to resolve, then re-stage and re-commit." >&2
  exit 1
fi

exit 0
