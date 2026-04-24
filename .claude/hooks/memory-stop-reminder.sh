#!/usr/bin/env bash
# Stop hook: remind the agent to run the memory skill if the session was substantive.
# Wired as a Claude Code `Stop` hook via settings.json.
# Fast, non-blocking — echoes a reminder to stdout and exits 0.

cat <<'EOF'
Session ending. If this session involved:
  - implementation progress, decisions, incidents, or user corrections
invoke the `memory` skill in end-of-session batch mode before stopping.
EOF

exit 0
