# Architecture

## Package map

| Package | Ngôn ngữ | Mục đích | Phụ thuộc vào |
|---------|---------|---------|--------------|
| `hermes/install/` | Bash | Cài Hermes Agent trên Termux + symlink config | (external: hermes-agent `.[termux]`) |
| `hermes/home/` | Markdown / YAML | Config-as-code default profile (agent Jarvis): SOUL.md, config.yaml, skills/ — symlink vào `~/.hermes/` | (read by Hermes at runtime) |
| `hermes/profiles/<name>/` | Markdown / YAML | Config-as-code named profile (vd `friday` — bot group least-privilege) — symlink vào `~/.hermes/profiles/<name>/` | (read by Hermes `-p <name>`) |
| `mcp-root/` | Python | MCP server root-level tools cho Hermes — on hold (cần root) | Hermes qua stdio/MCP |
| `device/` | Bash | Device safety scripts + Magisk module — on hold (cần root) | (system: /sys, Termux notify) |
| `stt-server/` | Docker / Python | whisper-live serving endpoint cho home server — sau | (external: collabora/whisperlive) |
| `android-assistant/` | Kotlin | TimezAssistant Android app — sau | Hermes, STT server (WebSocket) |

## Dependency direction

```
Current (Hermes pivot):
hermes/install/link-home.sh ──[symlink]──→ ~/.hermes/{SOUL.md, config.yaml, skills/}
Hermes Agent (Termux)       ──[https]────→ LiteLLM proxy (remote OpenAI-compatible model)
hermes gateway (default)    ──[Telegram]──→ bot Jarvis (full tool + device MCP, DM-only)
hermes -p friday gateway    ──[Telegram]──→ bot Friday → group (least-privilege: disabled_toolsets, no device MCP)
Termux:Boot ──[post-boot]──→ hermes/install/persistence/boot.sh (wake-lock + hermes; loop gateway mỗi profile có token)

Defer (cần root / native app):
Hermes ──[MCP/stdio]──→ mcp-root ──[su -c]──→ device/scripts (root safety tools)
android-assistant ──[ws]──→ Hermes ; ──[ws:9090]──→ stt-server (whisper-live)
```

## Key boundaries

**Phone chỉ chạy harness, model luôn remote.** Hermes không inference LLM trên phone; trỏ tới endpoint OpenAI-compatible (LiteLLM proxy) qua `config.yaml` + `.env`. Xem ADR: `docs/design-docs/hermes-agent-replaces-openclaw.md`.

**Config-as-code: chỉ asset durable được track.** `hermes/home/` (SOUL.md, config.yaml, skills/) symlink vào `~/.hermes/`; `.env` / `state.db` / `memories/` là runtime/secret, KHÔNG commit. Xem ADR: `docs/design-docs/hermes-config-as-code.md`.

**Gateway không được chạy as root (khi đã root).** Root access chỉ qua `mcp-root/server.py` với `USE_ROOT=true` → `su -c`. Hiện máy chưa root → mcp-root on hold. Xem ADR: `docs/design-docs/root-via-mcp.md`.

**Bot Telegram group = profile riêng, least-privilege.** Hermes KHÔNG gate tool theo user (approval về người trigger) → bot công khai cho group chạy ở profile `friday` (`hermes/profiles/friday/`) với `agent.disabled_toolsets` gỡ terminal/code_execution/file/device…, KHÔNG `mcp_servers`. Bot owner Jarvis (full tool) tách ở default profile, DM-only. Token Telegram khác nhau mỗi profile (Hermes chặn trùng). Xem ADR: `docs/design-docs/telegram-group-bot.md`.

**STT provider là interface, không concrete dependency.** (phase Android app sau) `android-assistant` phụ thuộc `STTProvider` interface, không phụ thuộc trực tiếp SherpaOnnx hay WhisperLive. Xem ADR: `docs/design-docs/stt-pluggable-provider.md`.

## Layer rules

- `android-assistant` không gọi root tools trực tiếp — tất cả phải qua Hermes → MCP (phase sau)
- `mcp-root` không biết về `android-assistant` — chỉ nhận commands từ Hermes
- `device/scripts` không phụ thuộc vào bất kỳ package nào trong repo — standalone shell scripts
- `hermes/home/` là runtime config (Hermes đọc qua symlink), KHÔNG import từ code khác
