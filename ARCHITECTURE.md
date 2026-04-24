# Architecture

## Package map

| Package | Ngôn ngữ | Mục đích | Phụ thuộc vào |
|---------|---------|---------|--------------|
| `openclaw-gateway/termux/` | Bash / Node.js | OpenClaw Gateway deploy script cho Termux | (external: openclaw npm) |
| `mcp-root/` | Python | MCP server cung cấp root-level tools cho Gateway | Gateway qua stdio |
| `device/` | Bash | Device safety scripts + Magisk module packaging | (system: /sys, Termux notify) |
| `stt-server/` | Docker / Python | whisper-live serving endpoint cho home server | (external: collabora/whisperlive) |
| `android-assistant/` | Kotlin | TimezAssistant Android app | Gateway (WebSocket), STT server (WebSocket) |
| `openclaw-gateway/workspace/` | Markdown | Agent workspace runtime docs (SOUL, IDENTITY…) | (read by OpenClaw at runtime) |
| `bak/` | — | Archived code, không dùng | (none) |

## Dependency direction

```
android-assistant
    ├──[ws:4000]──→ openclaw-gateway/termux  (OpenClaw Gateway)
    │                   └──[stdio]──→ mcp-root  (MCP server)
    │                                   └──[su -c]──→ device/scripts (root safety tools)
    └──[ws:9090]──→ stt-server  (whisper-live, home server, optional)

device/magisk-module ──[post-boot]──→ openclaw-gateway/termux/start.sh
                                  └──→ device/scripts/battery-guard.sh
                                  └──→ device/scripts/thermal-monitor.sh
```

## Key boundaries

**Gateway không được chạy as root.** Root access chỉ qua `mcp-root/server.py` với `USE_ROOT=true` → `su -c`. Xem ADR: `docs/design-docs/root-via-mcp.md`.

**STT provider là interface, không concrete dependency.** `android-assistant` phụ thuộc vào `STTProvider` interface, không phụ thuộc trực tiếp vào SherpaOnnx hay WhisperLive. Xem ADR: `docs/design-docs/stt-pluggable-provider.md`.

**`openclaw-gateway/workspace/` là runtime data, không phải code.** Không import, không hard-code path. OpenClaw tự quản lý.

## Layer rules

- `android-assistant` không gọi root tools trực tiếp — tất cả phải qua OpenClaw Gateway → MCP
- `mcp-root` không biết về `android-assistant` — chỉ nhận commands từ Gateway
- `device/scripts` không phụ thuộc vào bất kỳ package nào trong repo — standalone shell scripts
