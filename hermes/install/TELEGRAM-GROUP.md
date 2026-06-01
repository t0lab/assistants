# Bot Telegram công khai cho group — "Friday" (profile `friday`, least-privilege)

Một bot Telegram **thứ 2** tên **Friday** để cả một group hỏi-đáp / web search / đặt cronjob khi @mention — mà **không ai lộ được key hay chạy lệnh trên phone**. Đạt bằng một **profile riêng** (`friday`) gỡ sạch tool nhạy cảm; bot owner **Jarvis** (default profile) giữ full quyền, DM-only.

Quyết định + lý do (vì sao tách bot, không gate trong 1 bot): ADR [`telegram-group-bot.md`](../../docs/design-docs/telegram-group-bot.md). Plan: [`exec-plans/active/telegram-group-bot.md`](../../docs/exec-plans/active/telegram-group-bot.md).

## Kiến trúc

```
Group Telegram ──@mention──▶ Bot Friday  (@timezlab_friday_bot, token riêng)
                             └─ hermes -p friday gateway   (profile ~/.hermes/profiles/friday/)
                                ├─ toolset: web/search/cronjob/clarify/todo/vision  (KHÔNG terminal/code_exec/file/device)
                                └─ .env: TELEGRAM_GROUP_ALLOWED_CHATS + TELEGRAM_REQUIRE_MENTION; BotFather: Group Privacy OFF

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
- `/setprivacy` → **Disable** — **BẮT BUỘC** (verified on-device: Privacy ON thì @mention trong group **KHÔNG tới bot** → không bao giờ trả lời). Disable = bot nhận hết tin group; `TELEGRAM_REQUIRE_MENTION=true` lo việc chỉ *trả lời* khi mention. ⚠️ Sau khi đổi, **remove rồi add lại** bot vào group (Telegram cache privacy lúc join).

### 2. Gắn config-as-code (trên phone)
```bash
cd ~/t0lab/assistants && git pull
bash hermes/install/link-home.sh        # tự `hermes profile create friday` (nếu chưa có) + symlink config/SOUL
```
> `link-home.sh` loop mọi `profiles/<name>/`, **tự tạo profile chưa có** (idempotent) rồi symlink. Thêm profile sau = drop 1 dir vào `hermes/profiles/` + chạy lại script, không cần lệnh tay.

### 3. Điền `.env` — FILE RIÊNG của profile (secret + cấu hình telegram)
`~/.hermes/profiles/friday/.env` (KHÔNG phải `~/.hermes/.env`, KHÔNG commit).
⚠️ **KHÔNG để comment cùng dòng** (`KEY=value  # ...`) — giá trị dễ dính cả comment (đã làm hỏng token 1 lần). Comment để **dòng riêng** bắt đầu bằng `#`.
```bash
OPENAI_API_KEY=sk-...
TELEGRAM_BOT_TOKEN=<token bot Friday, không kèm gì>
TELEGRAM_REQUIRE_MENTION=true
TELEGRAM_ALLOWED_USERS=<your_user_id>
# TELEGRAM_GROUP_ALLOWED_CHATS điền ở bước 4 (sau khi có chat-id)
```
> Telegram allowlist/mention đi qua **ENV ở đây**, KHÔNG qua `config.yaml` (bản Hermes này bỏ qua `gateway.platforms.telegram.extra`). `your_user_id` lấy từ @userinfobot (để bạn DM riêng Friday; có thể bỏ).

### 4. Lấy group chat-id (từ chính bot, KHÔNG lấy từ URL web)
Add bot Friday vào group (đã Disable privacy + re-add ở bước 1), gửi `@timezlab_friday_bot test`. Rồi — **gateway phải TẮT** để getUpdates đọc được hàng đợi:
```bash
TG=$(grep -m1 '^TELEGRAM_BOT_TOKEN=' ~/.hermes/profiles/friday/.env | sed 's/^[^=]*=//; s/#.*//; s/[" ]//g')
curl -s "https://api.telegram.org/bot$TG/getUpdates" | python3 -m json.tool
```
Tìm message `chat.type: "supergroup"`, lấy **`chat.id`** (dạng `-100…`). ⚠️ Dùng id này, KHÔNG lấy từ URL `web.telegram.org` (có thể khác Bot-API id). Nếu getUpdates **rỗng** → privacy chưa Disable (bước 1) hoặc gateway chưa tắt. Thêm vào `.env`:
```bash
TELEGRAM_GROUP_ALLOWED_CHATS=-100...
```

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
⚠️ **Mỗi lần sửa `.env` phải restart gateway** (Ctrl-C + chạy lại) mới có hiệu lực — gateway chỉ nạp `.env` lúc start.
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
| @mention trong group bot **không nhận** (getUpdates chỉ có DM, không có tin group) | Group Privacy còn **ON** → Telegram không giao tin group cho bot | `/setprivacy`→**Disable** + **remove/add lại** bot (bài học chính: privacy ON là thủ phạm) |
| DM trả lời, **group không** | allowlist đặt sai chỗ (`gateway.platforms.telegram.extra` bị bỏ qua) hoặc sai tên var | đặt **`TELEGRAM_GROUP_ALLOWED_CHATS`** (có `GROUP_`) trong `.env`; KHÔNG phải `TELEGRAM_ALLOWED_CHATS` |
| Sửa `.env` mà bot không đổi hành vi | gateway chỉ nạp `.env` lúc start | restart gateway sau **mỗi** lần sửa `.env` |
| `getUpdates` trả **404** / token "dài bất thường" (~85+) | `.env` có **comment cùng dòng** → giá trị dính `# ...` | bỏ comment cùng dòng; để comment ở dòng riêng |
| chat-id sai → group bị deny | lấy id từ URL `web.telegram.org` (khác Bot-API id) | lấy `chat.id` từ `getUpdates` của chính bot |
| Gateway #2 không start, báo trùng token | 2 profile dùng chung token | mỗi profile 1 token riêng (Hermes chặn — 1 token chỉ 1 getUpdates) |
| Sau nâng cấp Hermes, tool lạ bật | không có allowlist native → tool mới **default-on** | re-audit `hermes -p friday tools`; thêm tool nguy hiểm mới vào `disabled_toolsets` |
| Cron job chạy được terminal | `disabled_toolsets` không phải sàn cứng cho cron | bỏ `cronjob` khỏi allowlist friday (Verify #4) |
