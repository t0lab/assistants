# Gateway — Termux Deploy

Deploy OpenClaw Gateway native trên phone (LineageOS + Magisk root).

**Status:** Phase 2 — chưa implement. Files sẽ được tạo ở đây.

## Files (planned)

| File | Mục đích |
|------|---------|
| `bootstrap.sh` | Idempotent setup: cài Node.js LTS, openclaw, Python deps trong Termux |
| `start.sh` | Khởi động Gateway với env vars, acquire wakelock |
| `mcp.json` | MCP server config cho Termux paths |
| `env.example` | Template env vars (API keys, tokens) |

## Requirements

- Termux từ F-Droid (không phải Play Store — Play Store version hết maintenance)
- LineageOS với Magisk root
- Node.js LTS (qua `pkg install nodejs-lts`)
- Port 4000 accessible từ localhost và Tailscale

## Quick start (sau khi implement)

```bash
# Lần đầu: chạy trong Termux
bash bootstrap.sh

# Mỗi lần start (hoặc tự động qua Magisk boot trigger)
bash start.sh
```

## Persistent startup

Magisk module `../device/magisk-module/` trigger `start.sh` sau boot (~60s delay).

## Xem thêm

- Exec plan Phase 2: `../../docs/exec-plans/active/timezassistant-platform.md`
- MCP root server: `../../mcp-root/README.md`
