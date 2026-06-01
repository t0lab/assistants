# Bot Telegram công khai cho group qua profile riêng (least-privilege)

**Status:** accepted
**Date:** 2026-06-01

## Context

Hiện tại có **1 bot Telegram** chạy ở default profile (`~/.hermes/`), gác bằng `TELEGRAM_ALLOWED_USERS` = chỉ owner. Bot này nạp `terminal` + `code_execution` + MCP `device` (Shizuku/rish) → ai điều khiển được nó = **RCE + điều khiển phone** (xem [WEB-ACCESS.md](../../hermes/install/WEB-ACCESS.md), ADR [device-control-via-adb.md](device-control-via-adb.md)).

Mong muốn mới: **mở cho cả một group Telegram hỏi-đáp + tạo cronjob khi @mention**, nhưng **không ai lộ được key (`.env`) hay execute trên hệ thống**.

Research 2026-06-01 (docs upstream Hermes Agent) cho ra các sự thật quyết định thiết kế:

1. **Hermes KHÔNG có gate tool theo user.** Allowlist chỉ quyết "ai được nói với bot", không có ACL kiểu owner-only-tool. `group_allow_admin_from` chỉ gate **slash command**, không gate việc agent gọi `terminal` khi được nhờ bằng câu chữ.
2. **Approval không phải boundary.** `approvals.mode: manual` đẩy prompt duyệt cho **chính người trigger** trong cùng chat, và họ **tự duyệt vĩnh viễn** được. Không có chế độ "chỉ owner mới duyệt".
   → Hệ quả: trong **1 bot**, rule ở SOUL.md ("chỉ owner chạy lệnh") **KHÔNG phải security boundary** — mạo danh hoặc prompt-injection từ nội dung group vượt được.
3. **Tool nhạy cảm chỉ tắt được ở mức instance (profile),** không per-user. Trong 1 bot, DM-của-owner và group dùng *chung* platform telegram → không thể "DM full, group hạn chế".
4. **Profile là khái niệm first-class.** Default = `~/.hermes/`; named = `~/.hermes/profiles/<name>/` (mỗi cái có riêng `config.yaml`/`.env`/`SOUL.md`/skills/memories/state.db). Cờ `-p <name>` cho mọi lệnh.
5. **Không chia sẻ được bot token.** Hermes từ chối gateway thứ 2 nếu trùng token; gốc rễ là Telegram chỉ cho **một** consumer `getUpdates`/token (process thứ 2 dính 409 Conflict).
6. **Không có allowlist toolset ở mức profile** — chỉ có denylist `agent.disabled_toolsets` (áp *sau* per-platform config, không platform nào override). Việc *chọn* toolset cho từng platform làm qua `hermes tools` (persist vào `config.yaml`).
7. **Cronjob có thể là đường escalation.** Cron chạy trong isolated agent session của gateway; `cronjob.create` có field `enabled_toolsets` mà *"khi set trên job thì thắng"* → một job có thể xin lại tool đã bị bỏ ở platform. CHỈ an toàn nếu `disabled_toolsets` là **sàn cứng** mà job không override được (phải verify on-device).
8. **Termux/Android không có Docker** → mitigation "chạy terminal trong container" mà upstream khuyên cho bot dùng-chung **không áp dụng được**.

## Decision

Tách một **profile `friday`** riêng (bot Telegram #2), least-privilege, phục vụ group qua mention-gating. Bot owner giữ nguyên ở default profile, DM-only.

1. **Profile mới `friday`** = `~/.hermes/profiles/friday/`; agent tên **Friday** (bot group). Default profile (`~/.hermes/`, full quyền) **không đổi** — agent tên **Jarvis** (bot owner). Usernames Telegram: `@timezlab_friday_bot` / `@timezlab_jarvis_bot`.
2. **Telegram của `friday`:** `group_allowed_chats = <chat id group>`, `require_mention: true`. Bot owner default giữ `TELEGRAM_ALLOWED_USERS = <owner>`, **không** group.
3. **Toolset 2 lớp (defense-in-depth, vì không có allowlist native):**
   - **Lớp chọn (allowlist-style):** qua `hermes -p friday tools`, chỉ bật cho platform telegram: `web` (search/extract), `cronjob`, `clarify`, `todo`, `vision`. *Không* bật media-gen (`image_gen`/`video_gen`/`tts`) lúc đầu (cost/abuse — thêm sau nếu cần).
   - **Lớp denylist cứng:** `agent.disabled_toolsets` liệt kê mọi thứ leak key / execute / điều khiển tài khoản khác: `terminal, code_execution, file, debugging, computer_use, memory, session_search, skills, delegation, messaging, discord, discord_admin, spotify, homeassistant, feishu_doc, feishu_drive, yuanbao`.
   - **MCP:** config của `friday` **không** khai `mcp_servers.device` (và mọi MCP khác) → không có tool device.
4. **Config-as-code generalize:** repo có `hermes/profiles/<name>/{SOUL.md, config.yaml, skills/}`; `link-home.sh` link **từng file** vào `~/.hermes/profiles/<name>/` (KHÔNG link cả thư mục runtime — `.env`/state/memories ở lại local). `boot.sh` **loop** qua `~/.hermes/profiles/*/`, profile nào có `TELEGRAM_BOT_TOKEN` thì start gateway riêng (`hermes -p <name> gateway`).
5. **Allowlist version-controlled:** `group_allowed_chats` + `require_mention` đặt trong `config.yaml` (commit, auditable); chỉ **token** ở `.env` (không commit).

## Alternatives considered

- **1 bot + rule prompt owner-gating (ý ban đầu)** — rejected: SOUL không phải boundary (sự thật #1, #2); mạo danh/injection vượt được; Hermes không enforce per-user tool.
- **1 bot + approval cho lệnh nguy hiểm** — rejected: approval đẩy về người trigger + tự-duyệt được; không có "owner-only approve".
- **`~/.hermes-group/` qua `HERMES_HOME` thủ công** — rejected: profile là cơ chế native (token-conflict check, layout chuẩn, `-p`), khỏi juggling env.
- **Allowlist toolset trong config** — không tồn tại ở Hermes; thay bằng per-platform select + denylist cứng.
- **Docker sandbox terminal cho bot chung** (upstream khuyên) — N/A trên Termux/Android (không có Docker).
- **`group_allow_from` = vài user tin cậy thay vì cả group** — không đạt yêu cầu "mọi người trong group"; và những người đó vẫn full tool.

## Consequences

**Better:**
- Cả group Q&A + cron **an toàn**: tool nhạy cảm *vật lý không nạp* → mạo danh/injection cũng không có gì để gọi.
- Owner giữ full quyền qua DM bot #1, tách hẳn khỏi bề mặt group.
- Enforce ở **mức instance**, không phụ thuộc model nghe lời.
- State/memory tách riêng → hội thoại group không làm bẩn memory/agent của owner.
- `link-home.sh`/`boot.sh` generalize → thêm profile sau = drop 1 dir, không sửa script.

**Worse:**
- Phải tạo + nuôi **bot #2** (BotFather) và thêm **1 gateway process** trên phone (tốn RAM/pin).
- Không có allowlist native → **denylist phải bảo trì**: Hermes update thêm toolset default-on có thể mở lỗ → **bắt buộc re-audit khi nâng cấp**.
- Cron mở cho group = bề mặt **lạm dụng** (spam job, tốn token model) kể cả khi tool đã bị giới hạn.
- 2 profile = 2 `.env` (2 lần điền `OPENAI_API_KEY` LiteLLM) cần giữ đồng bộ.

**Must now be true:**
- Profile `friday` **KHÔNG bao giờ** nạp: `terminal`, `code_execution`, `file`, `memory`, `messaging`, device MCP, hay tool điều khiển tài khoản khác.
- `agent.disabled_toolsets` là **sàn cứng** — đã verify cron **không** override được qua `enabled_toolsets`. (Nếu override được → **tắt `cronjob`** cho `friday`.)
- `group_allowed_chats` + `require_mention: true` bắt buộc; **không** dùng `*`.
- Token bot #2 chỉ ở `~/.hermes/profiles/friday/.env`, **không commit**.
- Bot owner (default profile) giữ `TELEGRAM_ALLOWED_USERS = owner`, DM-only — **không** thêm `group_allowed_chats`.
- Mỗi lần nâng cấp Hermes: chạy lại `hermes -p friday tools` xác nhận allowlist còn đúng (catalog toolset không phình thêm thứ nguy hiểm).

## Revisit if

- Hermes thêm **allowlist toolset thật** (`enabled_toolsets` mức profile) → chuyển sang allowlist, bỏ denylist dài + bỏ gánh nặng re-audit.
- Hermes thêm **per-user tool gating** → có thể cân nhắc gộp về 1 bot.
- Cron escalation **không chặn được** bằng `disabled_toolsets` → tắt `cronjob` cho `friday`, hoặc chờ upstream vá.
- Group cần agent **thao tác phone** → cân nhắc lại blast-radius; có thể tách thêm profile có device read-only + confirm (theo allow-list của device-control ADR), không nhét vào `friday`.
