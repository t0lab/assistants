---
name: phase-status
type: project
created: 2026-04-24
last-updated: 2026-05-29
---

# Phase Status

Exec plan hiện tại: `docs/exec-plans/active/hermes-pivot.md` (plan cũ OpenClaw: `timezassistant-platform.md` — một phần superseded)

| Phase | Nội dung | Status | Notes |
|-------|---------|--------|-------|
| P0 | Repo restructure | ✅ Done 2026-04-24 | skeletons created |
| Hermes pivot | Hermes Agent on Termux + config-as-code + persistence | 🔄 Active (2026-05-29) | T1 scaffold → T9 docs sweep; model qua LiteLLM proxy |
| P1 (cũ) | Device safety + Magisk module | ⛔ On hold | Cần root — máy đang stock HyperOS chưa root |
| P3 (cũ) | Root MCP server (`su -c`) | ⛔ On hold | Cần root |
| P4 (cũ) | STT server (whisper-live, home) | ⏳ Sau | Independent |
| P5 (cũ) | Android app + điều khiển phone như người thật | ⏳ Sau | Sau khi Hermes ổn định |

**Why:** Build personal always-on AI assistant self-hosted on phone; config tái cài dễ.
**How to apply:** When asked "what's next" or starting a new task, check this + `hermes-pivot.md` first.
