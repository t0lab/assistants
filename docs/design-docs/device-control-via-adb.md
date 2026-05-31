# Điều khiển thiết bị qua ADB shell privilege (Shizuku/MCP), không cần root

**Status:** accepted
**Date:** 2026-05-30

## Context

Mục tiêu xa của dự án: agent điều khiển phone "như người thật" — mở app, chụp màn hình, đọc UI, tap/gõ chữ. Docs cũ (`platform-architecture.md`, `root-via-mcp.md`, `CLAUDE.md`) gộp toàn bộ vào nhóm **"cần root → defer tới khi unlock"**. Research 2026-05-30 cho thấy điều đó **sai phần lớn** — và làm rõ bài toán thật ra có **2 lớp tách rời**:

- **Lớp quyền (privilege):** lấy quyền UID `shell` (2000) — đủ cho `input/screencap/uiautomator/am/pm` mà app thường không có. Hai cách không-root: **self-ADB** (`adb connect localhost` qua Wireless debugging) hoặc **Shizuku** (service `app_process` ở UID shell; Termux gọi qua `rish`).
- **Lớp tự động hoá (automation):** perception + action. Raw adb (`uiautomator dump` + `screencap` + `input`) / uiautomator2 (client HTTP-over-adb) / **Portal accessibility APK** (app, realtime, bền nhất).

Sự thật nền tảng (không-root, đã verify qua research):

1. **Mọi cơ chế quyền-shell đều chết sau reboot** — self-ADB lẫn Shizuku đều cần bắt tay lại qua Wireless debugging mỗi lần boot (mô hình bảo mật Android). Shizuku **có** cửa auto-start qua `WRITE_SECURE_SETTINGS`/Android-13+ trusted-wifi (MIUI/HyperOS hay chặn → phải test). Máy này dù sao cũng đã phải mở khoá tay sau reboot (FBE) nên thêm 1 bước one-tap chấp nhận được.
2. **`adb shell input text` KHÔNG gõ được Unicode/tiếng Việt** → bắt buộc dùng **ADBKeyBoard** (broadcast base64) hoặc clipboard/accessibility `setText`.
3. **Hermes bản Termux KHÔNG có sẵn tool device-control** (chỉ web/terminal/files/browser/media/memory/automation/MCP; browser automation còn bị bỏ qua) → phải tự thêm qua **MCP** (Hermes là MCP client). "Native Android UI actions" là của app F-Droid native, không phải bản pip/Termux.
4. Các framework dẫn đầu (OpenClaw/DroidClaw, DroidRun/Mobilerun, mobile-use) đều cùng công thức: perception = UI-tree + screenshot, action = adb input, **no root**; bản ổn-định-nhất luôn ship một **Portal accessibility APK**.

Ràng buộc thực tế:
- Máy: stock HyperOS, **chưa root, chưa unlock** → root path (`su -c`) vẫn blocked.
- Model remote `openai/Qwen/Qwen3.6-35B-A3B` **đọc-hiểu ảnh được** → screenshot dùng làm input thật (khi XML rỗng/animation, hoặc agent gửi ảnh hỏi user, hoặc user yêu cầu ảnh).
- Agent reachable qua Telegram + web (dashboard `--insecure` sau Cloudflare Access) → cho quyền thao tác phone = **blast radius rất lớn**.

## Decision

Phân pha, MCP làm interface ổn định xuyên suốt:

1. **MCP server ở `hermes/mcp/`** (Python, no-root) bọc quyền-shell. Hermes gọi như toolset qua `config.yaml > mcp_servers`. Tách biệt với `mcp-root/` (top-level, `su -c`, vẫn defer cần root).
2. **Backend quyền PLUGGABLE** (`rish` ↔ `adb shell`) sau một abstraction `run_shell()` → đổi cơ chế chỉ là đổi config, không sửa code tool.
   - **Pha 1 mặc định: Shizuku + `rish`** (ổn định hơn self-ADB cho always-on; ecosystem maintain tốt; có cửa auto-start). Self-ADB là fallback tối giản.
3. **Perception = XML là chính + screenshot khi cần.** `uiautomator dump` (element/text/bounds) rẻ và cho toạ độ chính xác → mặc định. `screencap` luôn sẵn: khi XML rỗng/không tin cậy, khi agent cần "gửi ảnh hỏi user", hoặc user yêu cầu ảnh — model đọc ảnh được nên dùng làm input thật.
4. **Action** qua backend: `input tap/swipe/text/keyevent`, `am start`/`monkey -p`, `screencap`. **Gõ tiếng Việt qua ADBKeyBoard** (cài IME, `ime set`, broadcast `ADB_INPUT_B64`), KHÔNG dùng `input text` cho chuỗi non-ASCII.
5. **Security — allow-list dễ cấu hình.** Tool **read-only** (`screenshot`, `dump_ui`, `list_packages`, `current_app`) thoáng; tool **write** (`tap/swipe/input_text/key/open_app/nav`) đi qua **allow-list + cổng confirm**, mặc định **deny**. Allow-list ở một file cấu hình **thân thiện cho user tự sửa** (vd `~/.hermes/device-policy.yaml`: liệt kê package được phép, bật/tắt confirm, chế độ read-only). Tài liệu hoá rủi ro Telegram/web.
6. **termux-api** (camera, hồng ngoại, sms-send, location, tts) là nhóm tool no-root **phụ**, ngoài UI-control.
7. **Pha 2 (sau, khi self/Shizuku chứng minh giá trị): Portal accessibility APK** = `android-assistant/` — tự sống qua reboot (BOOT_COMPLETED), realtime event (notification/SMS đến), gõ Unicode sạch. **MCP interface giữ nguyên**, chỉ đổi backend từ rish sang IPC tới app.
8. Self-ADB/Shizuku chỉ phục vụ **localhost**, không `adb tcpip` ra LAN/NetBird.

## Alternatives considered

- **Self-ADB làm backend chính** — chọn làm *fallback*, không phải primary: tối giản (không app phụ) nhưng port đổi mỗi reboot, reconnect khó tự động, socket adb-tcp dễ rớt. Backend pluggable nên vẫn dùng được.
- **uiautomator2 (v3)** — không chọn pha 1: giàu tính năng (UiSelector/XPath/wait/watcher, gõ Unicode qua clipboard) nhưng là **client HTTP-over-adb**, README không chứng minh chạy on-device Termux, và vẫn cần Lớp quyền bên dưới → thêm tầng phức tạp. Có thể xét sau nếu raw XML quá cực.
- **Portal accessibility APK ngay từ đầu** — deferred sang Pha 2: ổn định + đầy đủ nhất (đúng lý do các framework ship APK) nhưng phải build Kotlin + cầu IPC trước → lâu, chưa dùng được ngay.
- **Chờ root, làm tất cả qua `su -c`** — rejected: phần lớn không cần root; chặn tiến độ vô ích.
- **Gọi `am`/`input` trực tiếp trong Termux (không qua quyền shell)** — rejected: chạy ở UID app → `SecurityException`; cần UID shell (rish/adb).
- **Dựa hẳn vào screenshot+vision làm perception chính** — rejected: XML rẻ hơn và cho toạ độ chính xác; screenshot bổ trợ, không thay thế.

## Consequences

**Better:**
- Mở app / chụp / đọc UI / tap chạy được **ngay**, không chờ root/unlock, không build app.
- Backend pluggable → tự do đổi self-ADB ↔ Shizuku ↔ Portal-app mà không đụng tool code; nâng cấp Pha 2 ít rủi ro.
- Cùng phương pháp các framework đã chứng minh trên AndroidWorld.
- MCP tách biệt → audit + giới hạn quyền rõ ràng.

**Worse:**
- Không-root → vẫn cần một bước bắt-tay-quyền mỗi lần reboot (Shizuku/self-ADB); auto-start chỉ là *cửa*, chưa chắc chạy trên HyperOS.
- Thêm process MCP + (Pha 1) phụ thuộc Shizuku app & `rish` setup trong Termux.
- Mỗi action spawn `rish`/`adb` (đủ cho agentic, không cho high-FPS).
- ADBKeyBoard: phải cài 1 APK + set IME (đánh đổi để gõ được tiếng Việt).

**Must now be true:**
- Hermes (agent) **KHÔNG bao giờ** chạy root; UID `shell` (rish/adb) là trần quyền của device-control path.
- Mọi tool **write** qua allow-list + confirm; mặc định **deny**; allow-list ở file user tự sửa được.
- Quyền-shell chỉ phục vụ **localhost** — không expose adb ra mạng.
- Chuỗi non-ASCII (tiếng Việt) **luôn** đi qua ADBKeyBoard, không qua `input text`.
- Bật device-control = mở rộng blast-radius cho bot Telegram/web → **bắt buộc** giữ Cloudflare Access + `TELEGRAM_ALLOWED_USERS`.

## Revisit if

- **Có root** → mở rộng `mcp-root/` cho phần thật cần root (đọc `/data` app khác, `/sys`, kill process).
- Shizuku/self-ADB quá giòn hoặc cần realtime event/reboot-survival → nâng lên **Portal AccessibilityService APK** (Pha 2, `android-assistant/`); MCP interface giữ nguyên.
- Raw `uiautomator dump` quá cực để parse → xét lớp uiautomator2.
