# Root access qua MCP su -c, không chạy Gateway as root

**Status:** accepted
**Date:** 2026-04-24

## Context

Phone có Magisk root. OpenClaw cần thực thi root-level commands (đọc `/sys/class/power_supply`, kill processes, đọc `/data/`). Cách đơn giản nhất là chạy Gateway process as root. Tuy nhiên Gateway xử lý external content từ nhiều nguồn (Telegram, web, documents).

## Decision

Gateway chạy user-level. Một Python MCP server riêng (`mcp-root/server.py`) với `USE_ROOT=true` nhận commands từ Gateway qua stdio và thực thi qua `subprocess.run(["su", "-c", cmd])`. Gateway không bao giờ có root privileges trực tiếp.

## Alternatives considered

- **Chạy Gateway as root** — rejected. Prompt injection vào AI agent root = attacker có full device control. AI agents xử lý untrusted content liên tục (web pages, emails, Telegram messages từ người lạ).
- **Sudo whitelist cho Gateway user** — rejected. Whitelist sẽ cần cập nhật liên tục khi thêm tools mới; surface attack còn lớn.
- **Không cần root** — rejected. Một số tính năng thiết yếu (đọc battery temp từ `/sys`, kill processes, bảo vệ pin) yêu cầu root trên Android.

## Consequences

**Better:**
- Blast radius của prompt injection bị giới hạn — attacker chỉ có quyền user-level Gateway
- Root commands đi qua một interface rõ ràng, dễ audit
- MCP tools có thể validate/sanitize command trước khi thực thi

**Worse:**
- Thêm một process (mcp-root server) cần maintain
- Latency thêm ~1 round-trip stdio cho mỗi root command
- `su -c` timeout cần handle riêng (mặc định không có timeout)

**Must now be true:**
- Gateway process KHÔNG bao giờ có root — không `sudo`, không `su` trong Gateway code
- Tất cả root commands đi qua `execute_root_command()` trong `mcp-root/root_tools.py`
- `mcp-root/server.py` validate command string trước khi pass vào `su -c` (tránh shell injection)
- `USE_ROOT=true` env var phải explicit — server không tự assume root

## Revisit if

Android thêm capability system tốt hơn (như Linux capabilities) cho phép fine-grained permissions mà không cần full root — khi đó có thể bỏ `su -c` pattern.
