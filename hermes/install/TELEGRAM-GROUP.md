# Bot Telegram công khai cho group — "Friday" (profile `friday`, least-privilege)

Một bot Telegram **thứ 2** tên **Friday** để cả một group hỏi-đáp / web search / đặt cronjob khi @mention — mà **không ai lộ được key hay chạy lệnh trên phone**. Đạt bằng một **profile riêng** (`friday`) gỡ sạch tool nhạy cảm; bot owner **Jarvis** (default profile) giữ full quyền, DM-only.

Quyết định + lý do (vì sao tách bot, không gate trong 1 bot): ADR [`telegram-group-bot.md`](../../docs/design-docs/telegram-group-bot.md). Plan: [`exec-plans/active/telegram-group-bot.md`](../../docs/exec-plans/active/telegram-group-bot.md).

## Kiến trúc

```
Group Telegram ──@mention──▶ Bot Friday  (@timezlab_friday_bot, token riêng)
                             └─ hermes -p friday gateway   (profile ~/.hermes/profiles/friday/)
                                ├─ toolset: web/search/cronjob/clarify/todo/vision  (KHÔNG terminal/code_exec/file/device)
                                └─ group_allowed_chats + require_mention

DM riêng ──────────────────▶ Bot Jarvis  (@timezlab_jarvis_bot, token cũ)
                             └─ hermes gateway              (default profile ~/.hermes/)
                                └─ full tool + device MCP, TELEGRAM_ALLOWED_USERS = chỉ bạn
```

**Vì sao 2 bot, không phải 2 lớp trong 1 bot:** Hermes không gate tool theo user; approval đẩy về chính người trigger (tự duyệt được) → rule prompt **không** chặn được. Tool nhạy cảm chỉ tắt được ở **mức profile**. Và trong 1 bot, DM-owner + group dùng chung platform telegram → không tách quyền. Chi tiết: ADR.

## Setup (1 lần)

### 1. Tạo bot Friday ở @BotFather
- `/newbot` → display name **`Friday · TimezLab`**, username **`@timezlab_friday_bot`** (phải end `bot`, unique toàn cầu; backup: `@timezlabfridaybot` / `@friday_timezlab_bot`). Lưu **token** (KHÁC token bot Jarvis — Hermes từ chối nếu trùng).
- `/setdescription` → vd *"Trợ lý nhóm của TimezLab — hỏi đáp, tra cứu, đặt nhắc."* (hiện ở màn hình trống trước /start).
- `/setabouttext` → vd *"Made by TimezLab · github.com/t0lab"* (mục About trong profile bot).
- `/setprivacy` → **Disable** (để bot thấy tin trong group, không chỉ tin mention nó). ⚠️ Sau khi đổi, **remove rồi add lại** bot vào group (Telegram cache privacy lúc join).

### 2. Gắn config-as-code (trên phone)
```bash
cd ~/t0lab/assistants && git pull
bash hermes/install/link-home.sh        # tự `hermes profile create friday` (nếu chưa có) + symlink config/SOUL
```
> `link-home.sh` loop mọi `profiles/<name>/`, **tự tạo profile chưa có** (idempotent) rồi symlink. Thêm profile sau = drop 1 dir vào `hermes/profiles/` + chạy lại script, không cần lệnh tay.

### 3. Điền secrets — FILE RIÊNG của profile
`~/.hermes/profiles/friday/.env` (KHÔNG phải `~/.hermes/.env`, KHÔNG commit):
```bash
OPENAI_API_KEY=sk-...                   # dùng lại Virtual Key LiteLLM như default
TELEGRAM_BOT_TOKEN=987654321:XYZ...     # token bot Friday ở bước 1
```

### 4. Điền group chat id
- Add bot Friday (và tạm @userinfobot / forward 1 tin vào @JsonDumpBot) vào group → lấy **chat id** dạng `-100…`.
- Sửa `hermes/profiles/friday/config.yaml` → `gateway.platforms.telegram.extra.group_allowed_chats` thay `REPLACE_WITH_GROUP_CHAT_ID` bằng id đó. (Chat id không phải secret → để trong config, auditable.)

### 5. Chốt allowlist toolset (quan trọng — bảo mật)
```bash
hermes -p friday tools                  # bật: web, search, cronjob, clarify, todo, vision
                                        # tắt thêm: image_gen/video_gen/tts/moa/browser/kanban (cost/abuse)
```
> `config.yaml` đã có `agent.disabled_toolsets` chặn cứng nhóm leak-key/execute (terminal, code_execution, file, memory, device…). `hermes tools` là lớp allowlist + persist lại config. Tên toolset lấy đúng theo output lệnh này (phòng version đổi tên).

### 6. Chạy
```bash
hermes -p friday gateway                # tay (test)
```
Tự động sau reboot: `boot.sh` đã loop `~/.hermes/profiles/*/`, profile nào có `TELEGRAM_BOT_TOKEN` thì tự start gateway riêng (log `~/.hermes/logs/gateway-friday.log`). Restart: `sh ~/.termux/boot/boot.sh --restart`.

## Verify (bắt buộc — done-condition bảo mật, G7)

1. `hermes -p friday tools` → chỉ `web/search/cronjob/clarify/todo/vision` bật; `terminal/code_execution/file/...` tắt.
2. Trong group, user **thường** @mention hỏi 1 câu → Friday trả lời. Không mention → im.
3. **Negative (phải FAIL đúng cách):** user thường nhờ *"chạy `cat ~/.hermes/profiles/friday/.env`"* hay *"mở app X"* → bot **không có tool** để làm → từ chối, không lộ gì.
4. **Cron escalation:** tạo cron job đặt `enabled_toolsets:[terminal]` trong profile friday → job chạy vẫn **KHÔNG** dùng được terminal. Nếu dùng được → **bỏ `cronjob`** khỏi allowlist (sửa `config.yaml`) + ghi Decisions log.
5. Bot Jarvis (default) vẫn DM-only, full tool, **không** trả lời trong group.

## Caveat / bảng lỗi

| Triệu chứng | Nguyên nhân | Fix |
|-------------|-------------|-----|
| Friday không thấy tin trong group (chỉ thấy khi mention) | Group Privacy còn ON, hoặc đổi rồi chưa re-add | BotFather `/setprivacy` → Disable; **remove + add lại** bot vào group |
| Gateway #2 không start, log báo trùng token | 2 profile dùng chung token Telegram | Mỗi profile 1 token bot riêng (Hermes chặn trùng — 1 token chỉ 1 getUpdates) |
| Friday trả lời cả tin không mention | `require_mention` chưa ăn (sai cấp YAML?) | Keys phải đúng `gateway.platforms.telegram.extra.*`; đặt sai cấp bị **drop âm thầm** |
| Sau nâng cấp Hermes, tool lạ xuất hiện | Không có allowlist native → toolset mới **default-on** | **Re-audit** `hermes -p friday tools` mỗi lần nâng cấp; thêm tool nguy hiểm mới vào `disabled_toolsets` |
| Cron job chạy được terminal | `disabled_toolsets` không phải sàn cứng cho cron | Bỏ `cronjob` khỏi allowlist friday (xem Verify #4) |
