# Device Control — MCP + Shizuku/rish (no root), Pha 1

**Status:** active
**Created:** 2026-05-30
**Owner:** liamlee

## Goal

Hermes (Termux, no-root) điều khiển được phone "như người thật": **mở app, chụp màn hình, đọc UI, tap/swipe/gõ chữ (kể cả tiếng Việt)** — qua MCP server ở `hermes/mcp/`, lấy quyền shell qua **Shizuku + `rish`** (backend pluggable, self-ADB là fallback). Đạt tới mức agent hoàn thành tác vụ nhiều bước trên UI (vd "mở Settings, đọc trạng thái Wi-Fi", "mở app X gõ một câu tiếng Việt").

## Background

Quyết định + lý do ở ADR [`device-control-via-adb.md`](../../design-docs/device-control-via-adb.md). Tóm tắt: bài toán có 2 lớp — **quyền** (Shizuku/rish ↔ self-ADB, pluggable) và **automation** (raw adb pha 1; Portal APK pha 2). Sự thật cốt lõi: (a) không-root thì cơ chế quyền nào cũng chết sau reboot, cần bắt tay lại; (b) `adb input text` không gõ được tiếng Việt → ADBKeyBoard; (c) Qwen3.6 đọc ảnh được → screenshot là input thật, bổ trợ XML; (d) agent reachable qua Telegram/web → tool write phải allow-list + confirm.

`hermes/mcp/` (ADR này) **tách biệt** với `mcp-root/` (su -c, defer cần root) và `android-assistant/` (Portal APK — Pha 2).

## Tasks

- [ ] D1 — ADR device-control-via-adb ✅ (kèm plan này)
  - Done when: `docs/design-docs/device-control-via-adb.md` tồn tại (Context 2-lớp / Decision / Alternatives / Consequences / Revisit), link từ plan.

- [ ] D2 — Quyền shell: Shizuku + `rish` trong Termux (backend chính)
  - Done when: cài Shizuku, kích hoạt qua Wireless debugging (không-root); copy `rish` + `rish_shizuku.dex` vào `$PREFIX/bin`, set env; `rish -c 'id'` trả về `uid=2000(shell)`; `rish -c 'uiautomator dump /sdcard/ui.xml'` chạy. Tài liệu hoá bước kích hoạt lại sau reboot + thử cửa auto-start (`WRITE_SECURE_SETTINGS`/trusted-wifi) trên HyperOS (ghi rõ có chạy hay không).
  - Verify: `rish -c 'input keyevent 26'` bật/tắt màn hình.
  - Files: `hermes/install/device/shizuku-rish.md` (runbook), `hermes/install/device/setup-rish.sh`
  - ⚠️ Không-root: phải kích hoạt lại sau mỗi reboot trừ khi auto-start chạy. Self-ADB là fallback (D2b nếu cần).

- [ ] D2b — (fallback) Self-ADB localhost
  - Done when: runbook `pkg install android-tools` + `adb pair/connect 127.0.0.1:<port>`; abstraction `run_shell()` chọn backend qua env/config (`HERMES_DEVICE_BACKEND=rish|adb`). Chỉ làm nếu Shizuku không khả thi trên máy.
  - Files: `hermes/install/device/self-adb.md`

- [ ] D3 — `hermes/mcp/` MCP server: tool read-only + abstraction backend
  - Done when: `run_shell()` chạy lệnh qua backend (`rish`/`adb shell`); tools `screenshot()` (`screencap` → PNG), `dump_ui()` (`uiautomator dump` → JSON element/text/bounds), `list_packages()`, `current_app()`; khai báo trong `config.yaml > mcp_servers`; Hermes gọi `dump_ui` + `screenshot` ra kết quả thật. Screenshot trả ảnh để model đọc / gửi user.
  - Files: `hermes/mcp/server.py`, `hermes/mcp/shell_backend.py`, `hermes/mcp/device_tools.py`, `hermes/mcp/requirements.txt`, `hermes/mcp/README.md`, sửa `hermes/home/config.yaml`

- [ ] D4 — Tool write + security gate (allow-list dễ cấu hình)
  - Done when: `tap(x,y)`, `swipe`, `input_text`, `key(keycode)`, `open_app(pkg)`, `nav(back|home|recent)`; mọi tool write qua **allow-list + confirm**, mặc định **deny**; allow-list ở **`~/.hermes/device-policy.yaml`** user tự sửa (package whitelist, bật/tắt confirm, cờ read-only-mode); thao tác ngoài allow-list bị từ chối + log; mở được 1 app qua Hermes; thao tác ghi bị chặn nếu chưa cho phép.
  - Files: `hermes/mcp/device_tools.py`, `hermes/mcp/policy.py`, `hermes/home/device-policy.example.yaml`, `hermes/mcp/README.md`
  - ⚠️ Security: agent reachable qua Telegram/web → bắt buộc, không tuỳ chọn.

- [ ] D5 — Gõ tiếng Việt qua ADBKeyBoard
  - Done when: cài ADBKeyBoard APK, `ime set com.android.adbkeyboard/.AdbIME`; `input_text()` tự dùng broadcast `ADB_INPUT_B64` (base64) cho chuỗi non-ASCII, fallback `input text` cho ASCII; gõ được 1 câu tiếng Việt có dấu vào 1 ô text; runbook khôi phục IME mặc định.
  - Files: `hermes/mcp/device_tools.py`, `hermes/install/device/adbkeyboard.md`

- [ ] D6 — Skill `dieu-khien-phone`
  - Done when: skill hợp lệ (frontmatter + When to Use / Procedure / Pitfalls) hướng dẫn LLM loop **dump_ui (+ screenshot khi cần) → quyết định → tap/gõ**, pitfalls (chờ render, scroll tìm element, toạ độ từ bounds, khi nào chụp ảnh hỏi user); sau `link-home.sh` thì `hermes skills list` hiển thị; Hermes hoàn thành 1 tác vụ ví dụ nhiều bước.
  - Files: `hermes/home/skills/device/dieu-khien-phone/SKILL.md`

- [ ] D7 — (phụ, no-root) termux-api tools
  - Done when: ít nhất `camera_photo` + `infrared_transmit` gọi được (cần app Termux:API + `pkg install termux-api`); sms-send/location/tts tuỳ chọn.
  - Files: `hermes/mcp/termux_api_tools.py` hoặc `hermes/home/skills/device/termux-api/SKILL.md`

- [ ] D8 — Docs sweep: sửa khẳng định sai "UI control cần root"
  - Done when: `CLAUDE.md`, `.claude/memory/project/platform-architecture.md`, amendment ở `root-via-mcp.md`, Out-of-scope `hermes-pivot.md` phản ánh đúng (UI control/screenshot/camera/IR = no-root qua Shizuku/ADB/termux-api; chỉ /data app khác + /sys + intercept = root); `hermes/mcp/` thêm vào directory map + bảng stack `CLAUDE.md`.
  - Files: `CLAUDE.md`, `.claude/memory/project/platform-architecture.md`, `docs/design-docs/root-via-mcp.md`, `docs/exec-plans/active/hermes-pivot.md`

## Decisions log

- 2026-05-30: ADB shell-privilege (no-root) thay vì chờ root cho UI control. 2 lớp: **quyền** = Shizuku+rish (pluggable, self-ADB fallback); **automation** = raw adb (Pha 1) → Portal APK (Pha 2). Perception XML + screenshot (Qwen3.6 đọc ảnh). Tiếng Việt qua ADBKeyBoard. Tool write allow-list `~/.hermes/device-policy.yaml` + confirm (agent reachable qua Telegram/web). MCP ở `hermes/mcp/`. Lý do + alternatives ở ADR.

## Blockers

None để bắt đầu D2 trên máy thật. (D2–D7 có done-condition cần verify on-device trong Termux + cần cài Shizuku/ADBKeyBoard APK.)

## Out of scope

- Portal AccessibilityService APK / realtime event / reboot-survival tốt hơn → `android-assistant/` (Pha 2).
- Đọc `/data` app khác, `/sys`, kill process, intercept SMS/call tầng thấp → cần root (`mcp-root/`, blocked tới khi unlock).
- uiautomator2 layer (UiSelector/XPath) → chỉ xét nếu raw XML quá cực.
