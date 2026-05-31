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

## Tool (Pha 1 — read-only)

| Tool | Việc |
|------|------|
| `check_device()` | Kiểm tra backend chạy được (`id` → uid shell) |
| `dump_ui(only_interesting=True)` | Cây UI → element (text/desc/id/class + tâm + clickable) — **cách chính để "nhìn"** |
| `screenshot()` | Ảnh PNG màn hình (bổ trợ / gửi user) |
| `list_packages(third_party_only=True)` | Tên gói app đã cài |
| `current_app()` | App/Activity foreground |

Tool **write** (`tap/swipe/input_text/key/open_app/nav`) + allow-list/confirm + gõ tiếng Việt (ADBKeyBoard): **D4/D5** (đang tới).

## Cấu hình (env)

| Env | Mặc định | Ý nghĩa |
|-----|----------|---------|
| `HERMES_DEVICE_BACKEND` | `rish` | `rish` (Shizuku) hoặc `adb` (self-ADB) |
| `HERMES_DEVICE_TIMEOUT` | `30` | Timeout (giây) mỗi lệnh shell |
| `HERMES_DEVICE_SDCARD_REMOTE` | `/sdcard` | Nơi shell ghi file trung gian |
| `HERMES_DEVICE_SDCARD_LOCAL` | _(tự dò)_ | Đường Termux đọc /sdcard (`/storage/emulated/0`) |

## Bảo mật

Agent reachable qua Telegram + web → device-control = **blast radius lớn**. Pha 1 chỉ read-only; D4 thêm allow-list (`~/.hermes/device-policy.yaml`) + confirm cho tool write, mặc định **deny**. Giữ Cloudflare Access + `TELEGRAM_ALLOWED_USERS`. Backend chỉ phục vụ localhost.
