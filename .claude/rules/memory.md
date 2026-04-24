# Memory

Long-term memory splits by type:
- `user` / `feedback` → local (`~/.claude/projects/<hash>/memory/`)
- `project` / `reference` → committed (`.claude/memory/`)

Before writing, recalling, or consolidating memory, invoke the `memory` skill (or `memory-merge` for conflicts / oversized hot cache).
