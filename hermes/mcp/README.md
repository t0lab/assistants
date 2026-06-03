# hermes/mcp — MCP điều khiển thiết bị (no-root)

MCP server cho Hermes điều khiển phone "như người thật" — **không cần root**. Lấy quyền UID `shell` (2000) qua **Shizuku/rish** (mặc định) hoặc **self-ADB** (fallback), rồi dùng `uiautomator`/`screencap`/`input`/`am`.

Quyết định + lý do: [`../../docs/design-docs/device-control-via-adb.md`](../../docs/design-docs/device-control-via-adb.md). Plan: [`../../docs/exec-plans/active/device-control-adb.md`](../../docs/exec-plans/active/device-control-adb.md).

## Kiến trúc

```
Hermes (agent, user-level)
  └─ MCP stdio → server.py
        ├─ shell_backend.run_shell()   ← rish (Shizuku) | adb (self-ADB)   [đổi bằng env]
        ├─ device_tools  (perception)  ← uiautomator dump (XML) + screencap (PNG)
        └─ (D4) write + allow-list/confirm  ← input tap/swipe/text, am start
```

- **Quyền tách rời tự động hoá:** mọi lệnh đi qua `run_shell()` → đổi self-ADB↔Shizuku↔(sau)Portal-app chỉ là đổi backend, không sửa tool.
- **Perception:** XML là chính (rẻ, toạ độ chính xác); `screenshot()` bổ trợ (model Qwen3.6 đọc ảnh được; để gửi ảnh hỏi/báo user; khi XML rỗng).
- **File trung gian qua `/sdcard`:** `screencap`/`uiautomator` ghi ra `/sdcard`, Termux đọc lại (tránh hỏng nhị phân khi pipe qua rish/adb). Cần `termux-setup-storage` 1 lần.

## Cài

```bash
# 1) Quyền shell — Shizuku + rish (xem ../install/device/shizuku-rish.md)
#    Kích hoạt Shizuku qua Wireless debugging, đưa rish vào $PREFIX/bin, rồi:
rish -c 'id'        # mong: uid=2000(shell)

# 2) Deps MCP trong venv Hermes
cd ~/.hermes/hermes-agent && source venv/bin/activate
pip install -r ~/t0lab/assistants/hermes/mcp/requirements.txt

# 3) Termux đọc /sdcard (cho screenshot/dump)
termux-setup-storage
```

Đã khai báo sẵn trong `home/config.yaml > mcp_servers.device` (symlink vào `~/.hermes/`). Restart Hermes để nạp.

## Tool

**Đọc** (luôn chạy, không gate):

| Tool | Việc |
|------|------|
| `check_device()` | Kiểm tra backend chạy được (`id` → uid shell) |
| `dump_ui(only_interesting=True)` | Cây UI → element (text/desc/id/class + tâm + clickable) — **cách chính để "nhìn"** |
| `screenshot()` | Ảnh PNG màn hình (bổ trợ / gửi user) |
| `list_packages(third_party_only=True)` | Tên gói app (mặc định chỉ app bên thứ 3) |
| `find_package(keyword)` | Tìm package theo từ khoá trong **mọi** app (kể cả cài sẵn) — dùng trước `open_app` |
| `current_app()` | App/Activity foreground |

`device_info()` (đọc — pin/model/Android version) cũng không gate.

**Ghi** (qua cổng `~/.hermes/device-policy.yaml`, mặc định **CHẶN**):

| Tool | Việc |
|------|------|
| `tap(x,y)` | Chạm toạ độ (lấy từ `center` của dump_ui) |
| `swipe(x1,y1,x2,y2,duration_ms=300)` | Vuốt |
| `key(keycode)` | Phím: số hoặc tên (back/home/recent/enter/del…) |
| `nav(back\|home\|recent)` | Điều hướng hệ thống |
| `input_text(text)` | Gõ chữ (kể cả tiếng Việt) qua ADBKeyBoard |
| `open_app(package)` | Mở app (chỉ gói trong `allowed_packages`) |
| `open_url(url)` | Mở link/deeplink (https/market:/wa.me/geo:/youtube search…) |
| `kill_app(package)` | Force-stop app |
| `toggle(target,on)` | wifi \| bluetooth \| airplane \| data |
| `brightness(0-255)` · `volume(up\|down\|mute)` · `lock_screen()` | Màn hình / âm lượng |
| `call(number)` · `sms_compose(number,body)` | Gọi/SMS — **cần `allow_telephony: true`** |

### Allow-list (Jarvis = full mặc định)

`hermes/home/device-policy.yaml` được `link-home.sh` symlink vào `~/.hermes/device-policy.yaml` → **Jarvis (default profile) full quyền sẵn** (`write_enabled/allow_all_packages/allow_telephony: true`). Muốn hạn chế: sửa file đó (`write_enabled: false` = chỉ đọc; `allow_all_packages: false` + liệt kê `allowed_packages`; `allow_telephony: false` chặn gọi/SMS).

Profile **`friday`** (group) KHÔNG khai `mcp_servers` → không nạp MCP device → file này không áp. Thiếu file / parse lỗi → `policy.py` mặc định **DENY** (sàn an toàn).

### Gõ tiếng Việt
`input_text` gõ qua **ADBKeyBoard** (`adb input text` không gõ được Unicode). Cài + set IME: xem [`../install/device/adbkeyboard.md`](../install/device/adbkeyboard.md).

## Cấu hình (env)

| Env | Mặc định | Ý nghĩa |
|-----|----------|---------|
| `HERMES_DEVICE_BACKEND` | `rish` | `rish` (Shizuku) hoặc `adb` (self-ADB) |
| `HERMES_DEVICE_TIMEOUT` | `30` | Timeout (giây) mỗi lệnh shell |
| `HERMES_DEVICE_SDCARD_REMOTE` | `/sdcard` | Nơi shell ghi file trung gian |
| `HERMES_DEVICE_SDCARD_LOCAL` | _(tự dò)_ | Đường Termux đọc /sdcard (`/storage/emulated/0`) |

## Gỡ rối rish (đã trả giá — đừng đào lại)

`run_shell` xử sẵn 3 quirk của rish/Shizuku; nếu refactor đừng bỏ:

1. **`RISH_APPLICATION_ID` không truyền qua process spawn** → rish in "RISH_APPLICATION_ID is not set" ra stdout + exit 0 + KHÔNG chạy lệnh. `shell_backend` tự `setdefault("com.termux")`; run_shell bắt sentinel này → raise (tránh "thành công giả").
2. **rish đẩy output sang STDERR thất thường** (cùng lệnh, lúc stdout lúc stderr — đã quan sát trực tiếp). → chạy subprocess với `stderr=STDOUT` (gộp). Đây là gốc của mọi flaky `pm list`/`find_package`/`open_app` trước đây.
3. **Output có thể bị cụt đuôi** khi capture. → bọc `<cmd>; printf '\n<MARK><rc>\n'`; thiếu marker = cụt → retry 3×; marker cũng để khôi phục đúng exit code.

Hệ quả: tool ĐỌC tự cứu/loud, không trả rỗng giả. `find_package` lọc substring trên máy (`pm list packages <kw>`) cho output nhỏ. Verified on-device 2026-06-03: find_package 8/8 ổn định.

## Bảo mật

Agent reachable qua Telegram + web → device-control = **blast radius lớn**. Pha 1 chỉ read-only; D4 thêm allow-list (`~/.hermes/device-policy.yaml`) + confirm cho tool write, mặc định **deny**. Giữ Cloudflare Access + `TELEGRAM_ALLOWED_USERS`. Backend chỉ phục vụ localhost.
