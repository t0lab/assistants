# TimezLab Assistants — Project Map

> Pointer map for AI agents. Keep this under ~100 lines.

## What This Does

Nền tảng trợ lý cá nhân: OpenClaw Gateway chạy trên phone (LineageOS+Root), Android assistant app với wake word + real-time voice conversation, STT server on-premise (RTX 3060).

## Stack

- **Polyglot Repo**: Mỗi thư mục ở root là một project độc lập.
- Gateway: Node.js (OpenClaw) + Python (MCP root server)
- Android app: Kotlin (TimezAssistant)
- STT server: Python/Docker (whisper-live + CUDA)
- Device scripts: Bash (Magisk module)

## Directory Map

| Dir | Vai trò |
|-----|---------|
| `openclaw-gateway/` | OpenClaw Gateway deployment |
| `openclaw-gateway/termux/` | Deploy trên phone (LineageOS + Termux) |
| `openclaw-gateway/workspace/` | Agent workspace: AGENTS, SOUL, MEMORY |
| `openclaw-gateway/state/` | Runtime state (OpenClaw managed) |
| `openclaw-gateway/skills/` | OpenClaw skills |
| `device/` | Device safety scripts + Magisk module |
| `mcp-root/` | Root-capable MCP server (Python) |
| `stt-server/` | whisper-live Docker setup (home server, RTX 3060) |
| `android-assistant/` | TimezAssistant Android app (Kotlin) |
| `bak/` | Code cũ không còn dùng (Docker gateway) |
| `docs/exec-plans/active/` | Exec plans đang thực thi |

## Docs

| Khi cần... | Đọc |
|-----------|-----|
| Hiểu cấu trúc module, dependency | `ARCHITECTURE.md` |
| Product direction, non-goals, roadmap | `docs/DESIGN.md` |
| Tasks chi tiết từng phase | `docs/exec-plans/active/timezassistant-platform.md` |
| Lý do một quyết định kỹ thuật | `docs/design-docs/<topic>.md` |
| Known tech debt và workarounds | `docs/exec-plans/tech-debt-tracker.md` |
| Quy tắc AI agent | `CLAUDE.md` |
