# Dùng Hermes Agent (Nous Research) thay OpenClaw làm agent gateway

**Status:** accepted
**Date:** 2026-05-29
**Deciders:** liamlee

## Context

OpenClaw từng là "não" gateway của dự án (chạy Node.js trên Termux). Người dùng quyết định chuyển sang **Hermes Agent** ([github.com/NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent), MIT): model-agnostic (200+ model qua endpoint OpenAI-compatible), self-improving (tự viết skill markdown tái dùng sau task ≥5 tool calls), **có đường cài Termux chính thức** (`.[termux]` extra, trang docs `getting-started/termux`), native tool-calling + MCP client.

Cùng lúc, research làm rõ một sai lệch trong docs cũ: thiết bị **đang ở stock HyperOS, CHƯA root, CHƯA unlock bootloader** — không phải "LineageOS + Magisk" như [CLAUDE.md](../../CLAUDE.md)/[ARCHITECTURE.md](../../ARCHITECTURE.md) ghi. Vì 6GB RAM không kham nổi LLM, model chạy remote qua **LiteLLM proxy** (OpenAI-compatible) của người dùng; điện thoại chỉ chạy harness.

## Decision

Thay OpenClaw bằng **Hermes Agent** cài native trong Termux qua đường `.[termux]` chính thức. Harness chạy trên phone, **model luôn ở remote** (LiteLLM proxy: `OPENAI_BASE_URL` + `OPENAI_API_KEY` trong `.env`, tên model trong `config.yaml`). Giữ nguyên quyết định Termux-native (bổ sung cho `gateway-on-termux.md`). Các khả năng "tương tác như người thật" (điều khiển UI app, screenshot im lặng, đọc data app khác, hồng ngoại) và mọi thứ phụ thuộc root được **defer sang phase sau**; trọng tâm hiện tại là một setup Hermes **ổn định và tái sử dụng được** (xem `hermes-config-as-code.md`).

## Alternatives considered

- **Giữ OpenClaw** — rejected. Người dùng muốn skill tự-tích-lũy + linh hoạt 200+ model + config dạng file dễ version. Hermes còn có sẵn `hermes claw migrate` import từ OpenClaw.
- **Chạy LLM trên phone** — rejected. 6GB RAM không đủ; harness Hermes tách rời model nên không cần.
- **Self-host model trên RTX 3060 ngay** — deferred. Chật với context lớn, latency voice-loop chưa kiểm chứng; người dùng đã có LiteLLM proxy. Revisit khi cần privacy tuyệt đối.
- **Gateway trên cloud VPS** — rejected (như `gateway-on-termux.md`): mất self-host/privacy, cần server always-on.

## Consequences

**Better:**
- Đổi model chỉ bằng sửa `config.yaml` (model-agnostic).
- Skill tự-cải-thiện tích lũy kiến thức tái dùng giữa các session.
- Termux được hỗ trợ chính thức → ít rủi ro "tự chế".
- Native MCP → tái dùng `mcp-root/` ở phase sau mà không đổi kiến trúc.
- Cấu hình là file phẳng (SOUL.md, skills/, config.yaml) → version-control được (xem `hermes-config-as-code.md`).
- Chạy harness **không cần root**.

**Worse:**
- Hermes rất mới (release 2026-02-25), API/extra thay đổi nhanh → phải pin version, re-verify mỗi lần update.
- Persistence nền trên HyperOS chưa-root là "best-effort" (phantom-process killer, Doze) và khó kiểm soát hơn nếu không có root.
- Bước `pip install` có thể OOM trên 6GB (build Rust/C: `pydantic-core`, `tiktoken`) → cần swap + prebuilt wheels.
- Các tính năng "như người thật" phụ thuộc root bị **chặn** cho tới khi unlock bootloader.
- Thêm một hệ sinh thái mới phải học.

**Must now be true:**
- Phone chỉ chạy harness Hermes; LLM **luôn** là endpoint OpenAI-compatible remote. **Không** inference LLM trên phone.
- Tên model đặt ở `config.yaml` (`model.default`), **KHÔNG** ở `.env` — `MODEL_NAME`/`LLM_MODEL` không được Hermes đọc.
- Secrets (`OPENAI_API_KEY`, bot token) chỉ nằm trong `~/.hermes/.env`, **không bao giờ** commit (xem `hermes-config-as-code.md`).
- `openclaw-gateway/` cũ được archive vào `bak/`, không sync.
- Mọi doc nói thiết bị "LineageOS + root" là **sai** tính tới 2026-05-29; thiết bị là stock HyperOS, unrooted. Khả năng phụ thuộc root phải đánh dấu "blocked tới khi unlock bootloader".
- Gateway **KHÔNG** chạy as root (giữ nguyên lý do của `root-via-mcp.md` — càng đúng với agent xử lý nội dung untrusted).

## Revisit if

Hermes không thể chạy ổn định trên Termux/HyperOS (bị kill liên tục dù đã mitigate); HOẶC người dùng root máy (mở lại các khả năng đã defer); HOẶC quyết định self-host model trên home server.
