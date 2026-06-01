# TimezLab Assistants — Project Map

> Pointer map for AI agents. Keep this under ~100 lines.

## What This Does

Nền tảng trợ lý cá nhân: **Hermes Agent** chạy trên phone qua Termux (Redmi Note 11S, stock HyperOS — chưa root), model remote qua LiteLLM proxy (OpenAI-compatible). Mục tiêu xa: điều khiển phone như người thật + Android voice app (defer tới khi Hermes ổn định + máy root).

## Stack

- **Polyglot Repo**: Mỗi thư mục ở root là một project độc lập.
- Agent: Hermes Agent (Python) qua Termux + config-as-code trong `hermes/`
- MCP root server: Python (`mcp-root/`) — on hold (cần root)
- Android app: Kotlin (TimezAssistant) — sau
- STT server: Python/Docker (whisper-live + CUDA) — sau
- Device scripts: Bash (Magisk module) — on hold (cần root)

## Directory Map

| Dir | Vai trò |
|-----|---------|
| `hermes/` | **Hermes Agent config-as-code + Termux install** (active) |
| `hermes/home/` | Asset symlink vào `~/.hermes/` (default profile, agent Jarvis): SOUL.md, config.yaml, skills/ |
| `hermes/profiles/` | Named profile → `~/.hermes/profiles/<name>/` (vd `friday` — bot group Friday, least-privilege) |
| `hermes/install/` | bootstrap.sh, link-home.sh, persistence/, TELEGRAM-GROUP.md |
| `mcp-root/` | Root-capable MCP server (Python) — on hold (cần root) |
| `device/` | Device safety scripts + Magisk module — on hold (cần root) |
| `stt-server/` | whisper-live Docker (home server, RTX 3060) — sau |
| `android-assistant/` | TimezAssistant Android app (Kotlin) — sau |
| `docs/exec-plans/active/` | Exec plans đang thực thi |

## Docs

| Khi cần... | Đọc |
|-----------|-----|
| Hiểu cấu trúc module, dependency | `ARCHITECTURE.md` |
| Product direction, non-goals, roadmap | `docs/DESIGN.md` |
| Tasks đang thực thi (Hermes pivot) | `docs/exec-plans/active/hermes-pivot.md` |
| Vì sao Hermes / config-as-code | `docs/design-docs/hermes-agent-replaces-openclaw.md`, `hermes-config-as-code.md` |
| Bot Telegram group (least-privilege, 2-profile Jarvis/Friday) | `docs/design-docs/telegram-group-bot.md`, setup `hermes/install/TELEGRAM-GROUP.md` |
| Plan cũ (OpenClaw, một phần superseded) | `docs/exec-plans/active/timezassistant-platform.md` |
| Lý do một quyết định kỹ thuật | `docs/design-docs/<topic>.md` |
| Known tech debt và workarounds | `docs/exec-plans/tech-debt-tracker.md` |
| Quy tắc AI agent | `CLAUDE.md` |
