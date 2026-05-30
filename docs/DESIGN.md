# TimezLab Assistants — Product Design

## Problem

Các voice assistant hiện tại (Google Assistant, Siri) hoạt động theo mô hình single-turn: mỗi câu hỏi là một lệnh độc lập, không có context carry-over, phải nói wake word lại liên tục. Đồng thời, tất cả đều phụ thuộc cloud của bên thứ ba — audio gửi ra ngoài, không có privacy.

## Product direction

**Phase hiện tại:** Hermes pivot — đưa **Hermes Agent** chạy ổn định trên Termux + config-as-code (P0 done; P1–P5 cũ re-scoped/on-hold).

Mục tiêu: phone trở thành personal AI assistant always-on — chạy self-hosted trên chính thiết bị, model qua LiteLLM proxy remote, cấu hình version-control để tái cài dễ. Mục tiêu xa: điều khiển phone như người thật + voice conversation.

## What success looks like

1. Nói wake word → assistant trả lời trong < 2s
2. Nói tiếp mà không cần wake word lại (multi-turn conversation)
3. Assistant hiểu tiếng Việt đủ tốt để dùng hàng ngày
4. Phone hoạt động 24/7 mà không quá nóng hoặc hao pin nhanh
5. Khi ra ngoài mạng nhà: assistant vẫn hoạt động qua 4G + Tailscale

## Non-goals

- Không cạnh tranh với Google Assistant về breadth of integrations
- Không build voice assistant cho nhiều người dùng — đây là personal tool
- Không release lên Play Store — side-load only
- Không local LLM trên phone — model chạy remote qua LiteLLM proxy (OpenAI-compatible)
- (Đổi 2026-05-29) Trước dùng OpenClaw; nay dùng Hermes Agent — xem `docs/design-docs/hermes-agent-replaces-openclaw.md`

## Components

| Component | Vai trò người dùng nhìn thấy |
|-----------|------------------------------|
| Hermes Agent (Termux) | "Não" — xử lý intent, gọi tools, nhớ context, tự học skill |
| LiteLLM proxy (remote) | Model LLM — phone không chạy LLM |
| TimezAssistant app | (sau) App hàng ngày — wake word, voice conversation |
| whisper-live (home server) | (sau) Tai — STT chính xác cao khi ở nhà |
| Device safety scripts | (sau, cần root) Chạy ngầm — cảnh báo pin/nhiệt |

## Roadmap (phases)

- **P0** ✅ Repo restructure (2026-04-24)
- **Hermes pivot** (active, 2026-05-29) — Hermes Agent on Termux + config-as-code + persistence
- **On-hold (cần root):** device safety + Magisk (P1 cũ), root MCP server (P3 cũ)
- **Sau:** whisper-live STT (P4 cũ), TimezAssistant Android app + điều khiển phone như người thật (P5 cũ)

Chi tiết task hiện tại: `docs/exec-plans/active/hermes-pivot.md` (plan cũ: `timezassistant-platform.md`)
