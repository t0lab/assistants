# Bot group Telegram "Friday" (profile `friday`) — Q&A/cron, least-privilege

**Status:** active
**Created:** 2026-06-01
**Owner:** liamlee

## Goal

Một **bot Telegram thứ 2** cho group: thành viên @mention để **hỏi-đáp + web search + tạo cronjob**, mà **không thể lộ key (`.env`) hay execute trên phone**. Đạt bằng một **profile `friday`** riêng (bot #2) với toolset least-privilege; bot owner (default profile) giữ full quyền, DM-only. Done tổng thể: trong group, một user-thường mention bot → trả lời được câu hỏi/ cron; nhưng yêu cầu chạy lệnh shell / đọc `.env` / điều khiển phone đều **bất khả thi vì tool không tồn tại**.

## Background

Quyết định + lý do ở ADR [`telegram-group-bot.md`](../../design-docs/telegram-group-bot.md). Tóm tắt sự thật cốt lõi: (a) Hermes không gate tool theo user, approval đẩy về người trigger → **rule prompt không phải boundary**; (b) tool nhạy cảm chỉ tắt được ở **mức profile**, không per-user trong 1 bot; (c) **profile** là cơ chế native (`~/.hermes/profiles/<name>/`, cờ `-p`); (d) **không chia sẻ được token** (Telegram 1 getUpdates/token); (e) không có allowlist toolset → dùng per-platform select (`hermes tools`) + denylist cứng (`disabled_toolsets`); (f) **cron có thể escalate** qua `enabled_toolsets` per-job → phải verify.

Liên quan: [WEB-ACCESS.md](../../../hermes/install/WEB-ACCESS.md) (dashboard/Access), [device-control-via-adb.md](../../design-docs/device-control-via-adb.md) (device MCP — KHÔNG đưa vào `friday`).

## Tasks

- [x] G1 — ADR + exec plan
  - Done when: `docs/design-docs/telegram-group-bot.md` (Context/Decision/Alternatives/Consequences/Revisit) + plan này tồn tại, link nhau.

- [x] G2 — Config-as-code cho profile `friday` ✅ 2026-06-01
  - Done when: `hermes/profiles/friday/SOUL.md` (persona "trợ lý Q&A của group", tiếng Việt, nêu rõ phạm vi: trả lời/search/cron, không thao tác phone/secrets) + `hermes/profiles/friday/config.yaml` (reuse block `providers.litellm` + `model`; `security.allow_lazy_installs: false`; `agent.disabled_toolsets: [terminal, code_execution, file, debugging, computer_use, memory, session_search, skills, delegation, messaging, discord, discord_admin, spotify, homeassistant, feishu_doc, feishu_drive, yuanbao]`; `gateway.platforms.telegram.extra` với `group_allowed_chats` + `require_mention: true`; **KHÔNG** `mcp_servers`) + `hermes/profiles/friday/skills/.gitkeep`.
  - Files: `hermes/profiles/friday/{SOUL.md, config.yaml, skills/.gitkeep}`
  - ⚠️ `config.yaml` KHÔNG chứa token/secret. `group_allowed_chats` để placeholder + comment cách lấy chat id.

- [x] G3 — Generalize `link-home.sh` (link mọi profile) ✅ 2026-06-01 (verified `HERMES_HOME=/tmp` + idempotent)
  - Done when: bóc logic link thành hàm `link_profile <repo_dir> <hermes_dir>`; gọi cho `home/`→`$HERMES_HOME` (như cũ) và loop `profiles/*/`→`$HERMES_HOME/profiles/<name>/`; chỉ link `SOUL.md`/`config.yaml`/`skills/<skill>` (KHÔNG `.env`/state/memories); idempotent; chạy lại không vỡ default. `--help` mô tả hành vi mới.
  - Files: `hermes/install/link-home.sh`
  - Verify: chạy `bash link-home.sh` (máy dev, `HERMES_HOME=/tmp/h`) → `/tmp/h/profiles/friday/{SOUL.md,config.yaml}` là symlink trỏ về repo; `home/` vẫn link đúng.

- [x] G4 — `boot.sh` auto-start gateway mọi profile có token ✅ 2026-06-01 (sh/bash -n OK; loop logic verified; full boot test còn ở G7 on-device)
  - Done when: sau gateway default, **loop** `~/.hermes/profiles/*/`; profile nào `\.env` có `TELEGRAM_BOT_TOKEN` → `start_bg 'hermes -p <name> gateway' "$LOG_DIR/gateway-<name>.log" "$HERMES" -p <name> gateway`; nhánh `--restart` cũng `pkill -f 'hermes -p <name> gateway'` cho từng profile. Default gateway giữ nguyên (pattern `'hermes gateway'` không đụng `'hermes -p <name> gateway'`).
  - Files: `hermes/install/persistence/boot.sh`
  - ⚠️ Verify on-device: `hermes gateway --help` xem có `--all` không — nếu có, ghi chú nhưng vẫn dùng loop (chạy được bất kể).

- [x] G5 — `.env.example` + secrets cho profile ✅ 2026-06-01
  - Done when: `.env.example` thêm block hướng dẫn profile `friday`: tạo bot #2 ở BotFather, đặt token + `OPENAI_API_KEY` (LiteLLM, dùng lại value) vào **`~/.hermes/profiles/friday/.env`** (nêu rõ KHÁC `~/.hermes/.env` default); cảnh báo không commit; `TELEGRAM_GROUP_ALLOWED_CHATS` có thể để ở `.env` hoặc config (đã ở config G2).
  - Files: `hermes/.env.example`

- [x] G6 — Docs: setup + bảng lỗi ✅ 2026-06-01 (`hermes/install/TELEGRAM-GROUP.md` + README + persistence/README)
  - Done when: thêm tài liệu setup bot friday (BotFather tắt Group Privacy + remove/re-add bot vào group; `hermes profile create friday`; `link-home.sh`; `hermes -p friday tools` chọn allowlist; điền `.env`; thêm vào group) + verify steps; ghi rõ caveat re-audit toolset khi nâng cấp Hermes. Vị trí: section mới trong `hermes/README.md` hoặc file `hermes/install/TELEGRAM-GROUP.md` (link từ README + persistence/README).
  - Files: `hermes/install/TELEGRAM-GROUP.md` (hoặc README), cập nhật `hermes/README.md`, `hermes/install/persistence/README.md`

- [ ] G7 — Bring-up + verify on-device (security-critical)
  - Done when (tất cả phải đạt):
    1. `bash hermes/install/link-home.sh` → tự `hermes profile create friday` + `~/.hermes/profiles/friday/{config.yaml,SOUL.md}` là symlink repo. Xác nhận `hermes -p friday doctor` nhận profile (nếu Hermes nhận theo thư mục thì khỏi cần `profile create`).
    2. `hermes -p friday tools` xác nhận chỉ `web/cronjob/clarify/todo/vision` bật; `terminal`/`code_execution`/`file`/... tắt.
    3. Bot #2 trong group: user **thường** @mention hỏi 1 câu → trả lời (Q&A/search). Không mention → im.
    4. **Negative:** user thường nhờ "chạy `cat ~/.hermes/profiles/friday/.env`" / "mở app X" → bot **không có tool** để làm (từ chối, không lộ gì).
    5. **Cron escalation:** tạo cron job với `enabled_toolsets:[terminal]` trong profile friday → job chạy **KHÔNG** dùng được terminal. Nếu dùng được → bỏ `cronjob` khỏi allowlist (sửa G2) + ghi vào Decisions log.
    6. Default bot owner vẫn DM-only, full tool, không trả lời trong group.
  - ⚠️ Cần on-device (Termux) + tạo bot #2. Đây là done-condition bảo mật, không bỏ qua.

- [ ] G8 — Docs sweep  ⏳ 2026-06-01 phần 1 XONG
  - ✅ 2026-06-01: memory (`tech-decisions`/`platform-architecture`/`phase-status`/`hermes-gateway` + hot cache `project.md`/`reference.md`) + harness meta (`CLAUDE.md`/`AGENTS.md`/`ARCHITECTURE.md`) đã phản ánh mô hình 2-profile (Jarvis/Friday).
  - Done when (còn lại): các chỗ khẳng định "giữ `TELEGRAM_ALLOWED_USERS`" gắn liền blast-radius (device-control ADR, `hermes/mcp/README.md`, `shizuku-rish.md`) thêm 1 dòng: bot **friday** là profile riêng *không* có device/terminal nên không nằm trong blast-radius đó. `git-conventional` trước mỗi commit.
  - Files: `CLAUDE.md`, `.claude/memory/project/*.md`, `docs/design-docs/device-control-via-adb.md` (amendment), `hermes/mcp/README.md`

## Decisions log

- 2026-06-01: Tách **profile `friday`** (bot #2) thay vì gate trong 1 bot. Lý do: Hermes không có per-user tool gating, approval đẩy về người trigger → rule prompt không phải boundary; tool nhạy cảm chỉ tắt được ở mức profile. Toolset 2 lớp: `hermes tools` chọn allowlist (`web/cronjob/clarify/todo/vision`) + `agent.disabled_toolsets` denylist cứng; không `mcp_servers.device`. Config-as-code generalize `profiles/<name>/`. Đầy đủ + alternatives ở ADR.

## Blockers

- G7 cần **on-device** (Termux) + **bot Telegram #2** (BotFather). G2–G6 làm được trên máy dev.
- Câu hỏi mở verify ở G7.5: `disabled_toolsets` có chặn được cron `enabled_toolsets` escalation không — quyết định cron có ở `friday` hay không phụ thuộc kết quả này.

## Out of scope

- Cho group thao tác phone (device MCP) / terminal — **cố ý loại** khỏi `friday` (xem ADR "Revisit if").
- Per-user tool gating trong 1 bot — Hermes chưa hỗ trợ.
- media-gen (`image_gen`/`video_gen`/`tts`) cho `friday` — thêm sau nếu cần, cân nhắc cost/abuse.
- Owner profile / dashboard / cloudflared — không đổi (đã ở `hermes-pivot.md` + WEB-ACCESS).
