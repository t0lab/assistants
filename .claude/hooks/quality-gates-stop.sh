#!/usr/bin/env bash
# Stop hook: remind the agent to run fresh verification (test/lint/typecheck/build)
# before declaring the task done. Wired as a Claude Code `Stop` hook via settings.json.
# Fast, non-blocking — echoes a reminder to stdout and exits 0.

cat <<'EOF'
Session ending. Before declaring done, run fresh verification:
  - tests for changed code (not just "should pass" — actually run them)
  - typecheck / lint / build if the stack has them
  - manual verification for UI / CLI / integration behavior
If verification was not run on the final state, say so explicitly instead of
claiming success. See the `quality-gates` skill for the full protocol.
EOF

exit 0
