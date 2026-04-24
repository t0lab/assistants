# TimezLab Assistants — Product Design

## Problem

Các voice assistant hiện tại (Google Assistant, Siri) hoạt động theo mô hình single-turn: mỗi câu hỏi là một lệnh độc lập, không có context carry-over, phải nói wake word lại liên tục. Đồng thời, tất cả đều phụ thuộc cloud của bên thứ ba — audio gửi ra ngoài, không có privacy.

## Product direction

**Phase hiện tại:** Build nền tảng (P0 done, P1–P5 in progress).

Mục tiêu: phone trở thành personal AI assistant always-on — gọi tên là nói chuyện, có context nhớ xuyên suốt, chạy self-hosted trên chính thiết bị người dùng.

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
- Không thay thế OpenClaw — đây là interface layer lên OpenClaw
- Không local LLM trên phone — dùng cloud LLM API qua Gateway

## Components

| Component | Vai trò người dùng nhìn thấy |
|-----------|------------------------------|
| TimezAssistant app | App dùng hàng ngày — wake word, voice conversation |
| OpenClaw Gateway (Termux) | "Não" — xử lý intent, gọi tools, nhớ context |
| whisper-live (home server) | Tai — STT chính xác cao khi ở nhà |
| Device safety scripts | Chạy ngầm — user không thấy trừ khi có cảnh báo |

## Roadmap (phases)

- **P0** ✅ Repo restructure (2026-04-24)
- **P1** Device safety scripts + Magisk module
- **P2** OpenClaw Gateway on Termux + boot persistence
- **P3** Root MCP server (tools: battery, thermal, root shell)
- **P4** whisper-live STT server (home, RTX 3060)
- **P5** TimezAssistant Android app (wake word + voice session)

Chi tiết từng task: `docs/exec-plans/active/timezassistant-platform.md`
