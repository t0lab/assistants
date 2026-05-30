# Gateway chạy Termux native, không Docker

**Status:** accepted
**Date:** 2026-04-24

> **Amended 2026-05-29:** Quyết định "Termux-native, không Docker" vẫn giữ nguyên, nhưng phần mềm gateway đã đổi từ OpenClaw sang **Hermes Agent**. Xem `hermes-agent-replaces-openclaw.md`. Mọi chỗ trong doc này nói "OpenClaw Gateway" giờ đọc là "Hermes Agent harness".

## Context

OpenClaw Gateway cần chạy 24/7 trên phone (Redmi Note 11S, LineageOS + Magisk). Setup trước đó dùng Docker trên Linux host, phone chỉ là companion node app. Mục tiêu mới: phone tự chủ hoàn toàn, không cần server ngoài.

## Decision

Gateway chạy native trong Termux (Node.js LTS qua `pkg`), không Docker. Magisk module trigger `start.sh` sau boot. MCP servers cũng chạy trong Termux bằng Python.

## Alternatives considered

- **Docker trên phone** — rejected. Docker không hỗ trợ Android/ARM tốt nếu không có kernel namespace support đầy đủ; LineageOS không đảm bảo. Overhead quá cao cho thiết bị mobile.
- **Gateway trên cloud VPS, phone là node** — rejected. Cần internet liên tục, phụ thuộc ngoài, chi phí server. Mất lợi thế privacy/self-host.
- **Tiếp tục Docker trên Linux host** — rejected. Không self-contained; phone phụ thuộc laptop luôn bật. Không đáp ứng mục tiêu always-on mobile.

## Consequences

**Better:**
- Phone hoàn toàn standalone — mang đi đâu assistant đi đó
- Không cần server ngoài chạy 24/7
- Latency thấp hơn (localhost WebSocket vs LAN/internet)

**Worse:**
- Android có thể kill Termux background process — cần Magisk wakelock + foreground notification
- Node.js trong Termux tốn RAM (~200-300MB) và pin liên tục
- Update Gateway phức tạp hơn (không có docker pull)

**Must now be true:**
- `start.sh` phải acquire wakelock trước khi start Gateway
- Magisk module `service.sh` là entry point sau boot — không dùng Termux:Boot
- MCP paths dùng `/data/data/com.termux/files/home/...`, không dùng `/app/...` (Docker paths)
- `openclaw-gateway/docker/` trong `bak/` — không dùng nữa, không sync

## Revisit if

Phone RAM < 4GB hoặc thermal throttling liên tục do Gateway → cân nhắc offload về home server qua Tailscale.
