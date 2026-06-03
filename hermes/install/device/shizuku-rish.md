# Quyền shell không-root: Shizuku + rish (backend chính)

Cho MCP `hermes/mcp/` lấy quyền UID `shell` (2000) — đủ cho `input/screencap/uiautomator/am/pm` — **không cần root, không cần PC**. Backend mặc định của device-control (xem ADR [`device-control-via-adb.md`](../../../docs/design-docs/device-control-via-adb.md)). Fallback tối giản: [`self-adb.md`](./self-adb.md).

> ⚠️ **Không-root:** Shizuku **phải kích hoạt lại sau MỖI lần reboot** (giới hạn hệ thống). Xem mục Auto-start.

## Tiền đề
- Android 11+ (máy: HyperOS/Android, có Wireless debugging).
- **Developer options** bật; **Wireless debugging** bật (Settings → Developer options).

## Bước 1 — Cài Shizuku
F-Droid hoặc GitHub `RikkaApps/Shizuku` (gói `moe.shizuku.privileged.api`). Mở app 1 lần.

## Bước 2 — Kích hoạt Shizuku qua Wireless debugging (không PC)
Trong **Shizuku** → "Start via Wireless debugging":
1. Bật **Wireless debugging** trong Developer options (để màn này mở).
2. Shizuku → **Pairing** → đồng thời vào *Wireless debugging → Pair device with pairing code*, nhập mã Shizuku báo.
3. Shizuku → **Start**. Thấy "Shizuku is running" + version (vd r1091).

## Bước 3 — Đưa rish vào Termux
1. Lấy file `rish` + `rish_shizuku.dex` từ Shizuku app (menu **"Use Shizuku in terminal apps"** → lưu, vd ra `/sdcard/rish/`).
2. Trong Termux:
   ```bash
   termux-setup-storage      # cấp quyền đọc /sdcard (1 lần) — cần cho screenshot/dump
   bash ~/t0lab/assistants/hermes/install/device/setup-rish.sh /sdcard/rish
   ```
   Script copy `rish`+`*.dex` vào `$PREFIX/bin`, set `RISH_APPLICATION_ID=com.termux`, rồi test.
3. Lần đầu chạy `rish`, **Shizuku bật popup xin quyền cho Termux** → **Allow**.

## Bước 4 — Verify (done condition D2)
```bash
rish -c 'id'                          # mong: uid=2000(shell) ...
rish -c 'uiautomator dump /sdcard/hermes-ui.xml && echo OK'
rish -c 'input keyevent 26'           # bật/tắt màn hình → thấy có tác dụng
```
`uid=2000(shell)` ⇒ backend `rish` dùng được. MCP `hermes/mcp/` sẽ chạy lệnh qua đây.

## Env Android cho gateway (BẮT BUỘC để tool device chạy qua bot)

Tiến trình MCP do **gateway/Termux:Boot** (app `com.termux.boot`) spawn **thiếu** env Android runtime (`BOOTCLASSPATH`, `ANDROID_ROOT/DATA/ART_ROOT…`) mà shell interactive (app `com.termux`) có → `rish`→`app_process` không khởi động được ART VM → **trả rỗng câm** (mọi tool device "truncation"). `setup-rish.sh` đã tự **capture** các biến này vào `~/.hermes/android-env` (shell_backend nạp lúc chạy). Nếu chưa có, chạy tay **từ Termux interactive**:

```bash
env | grep -E '^(ANDROID|BOOTCLASSPATH|DEX2OATBOOTCLASSPATH)=' > ~/.hermes/android-env
```
Chạy lại sau mỗi **OS update** (BOOTCLASSPATH đổi). Path tĩnh (`ANDROID_ROOT=/system`…) thì shell_backend tự hardcode.

## Auto-start sau reboot (thử — HyperOS hay chặn)
Không-root thì phải kích hoạt lại mỗi boot. Các cửa (test xem máy có cho không):
- **Shizuku tự cấp `WRITE_SECURE_SETTINGS`** → tự bật Wireless ADB + tự start khi vào Wi-Fi tin cậy (Android 11+). Trên MIUI/HyperOS thường bị chặn.
- App **Automate**/Tasker chạy "Better Shizuku Starter" lúc boot/Wi-Fi connect.
- Nếu đều không được: chấp nhận mở Shizuku tap **Start** 1 lần sau mỗi reboot (máy này vốn đã phải mở khoá tay sau reboot do FBE).

Ghi lại kết quả test auto-start vào plan `device-control-adb.md` (D2).

## Bảo mật
`rish` = quyền shell cho mọi tiến trình Termux gọi nó. Agent reachable qua Telegram/web → giữ allow-list (D4) + Cloudflare Access + `TELEGRAM_ALLOWED_USERS`. Không expose adb/Shizuku ra mạng.

## Nguồn
- Shizuku setup (Wireless debugging): https://shizuku.rikka.app/guide/setup/
- rish: https://github.com/RikkaApps/Shizuku-API/blob/master/rish/README.md
- Termux + Shizuku + rish (Android 14): https://oddity.oddineers.co.uk/2024/01/14/termux-shizuku-and-rish-configuration-for-android-14/
