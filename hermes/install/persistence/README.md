# Persistence — giữ Hermes/SSH sống trên HyperOS chưa-root

Máy chưa root → không có Magisk `service.sh`/systemd. Cách giữ tiến trình nền sống dùng 3 lớp, không cần root:

| Lớp | Công cụ | Chống điều gì |
|-----|---------|---------------|
| Boot tự chạy | **Termux:Boot** → `boot.sh` | reboot làm mất `sshd`, wake-lock |
| Không ngủ CPU | `termux-wake-lock` (trong `boot.sh`) | Doze giết tiến trình nền |
| Không bị OS dọn | thao tác tay HyperOS + `adb-tweaks.sh` | autostart/battery + phantom-process killer |

## File

- **`boot.sh`** — chạy lúc khởi động (qua Termux:Boot). Tự bật (idempotent, không dup): wake-lock, `sshd`, `hermes gateway` (Telegram, default profile), `hermes -p <name> gateway` cho mỗi named profile có `TELEGRAM_BOT_TOKEN` (vd `friday` — bot group, xem [`../TELEGRAM-GROUP.md`](../TELEGRAM-GROUP.md)), `hermes dashboard` (web UI), `cloudflared` (tunnel — token từ `.env`).
- **`adb-tweaks.sh`** — chạy **trên PC** qua adb: tắt phantom-process killer (Android 12+/HyperOS hay giết tiến trình nền của Termux).

> **Tiền đề cho boot.sh chạy đủ:** đã cài `hermes dashboard`'s extras (`pip install -e '.[web,pty]'`), `cloudflared` (`pkg install cloudflared`), và đã chạy `hermes dashboard` tay **1 lần** để build frontend (npm). `.env` cần `TELEGRAM_*` (Telegram) và `CLOUDFLARE_TUNNEL_TOKEN` (tunnel) — không có thì boot.sh tự bỏ qua phần đó. Named profile (vd `friday`) đọc `~/.hermes/profiles/<name>/.env` riêng — thiếu `TELEGRAM_BOT_TOKEN` thì boot bỏ qua gateway của profile đó. Chi tiết web UI: [`../WEB-ACCESS.md`](../WEB-ACCESS.md), bot group: [`../TELEGRAM-GROUP.md`](../TELEGRAM-GROUP.md).

---

## 1. Thao tác tay HyperOS (làm 1 lần)

Đã mô tả ở [`../SETUP-PHONE.md`](../SETUP-PHONE.md) **Bước 2** — cần đủ:
- Battery → **No restrictions** cho Termux
- **Autostart ON** cho **Termux** *và* **Termux:Boot** (Boot bắt buộc, không có thì `boot.sh` không chạy)
- Tắt "Tạm dừng hoạt động ứng dụng nếu không dùng"
- Khóa (🔒) thẻ **Termux** trong Recent apps

> **SSH sau reboot cần NetBird tự lên.** `boot.sh` bật `sshd`, nhưng IP `100.97.86.95` là của NetBird — VPN chưa lên thì laptop báo `No route to host`. Cách cho NetBird tự kết nối lúc boot (+ lưu ý khoá-màn-hình/FBE): xem [`../SETUP-PHONE.md`](../SETUP-PHONE.md) **Bước 3d**.

## 2. Cài Termux:Boot script

Cần app **Termux:Boot** đã cài + **mở 1 lần** sau khi cài (để nó đăng ký nhận boot), và Autostart đã bật (mục 1). Rồi trên phone:

```bash
mkdir -p ~/.termux/boot
ln -sf ~/t0lab/assistants/hermes/install/persistence/boot.sh ~/.termux/boot/boot.sh
chmod +x ~/t0lab/assistants/hermes/install/persistence/boot.sh
```

> Symlink để sửa trong repo (`git pull`) là có hiệu lực ngay. Nếu Termux:Boot **không chạy** symlink (vài bản kén), fallback copy thật:
> `cp ~/t0lab/assistants/hermes/install/persistence/boot.sh ~/.termux/boot/boot.sh && chmod +x ~/.termux/boot/boot.sh`

Bật trước khi reboot để kiểm:
```bash
sh ~/.termux/boot/boot.sh      # boot mode: start cái CHƯA chạy (idempotent, không kill)
cat ~/.hermes/logs/boot.log    # thấy: wake-lock, sshd, hermes gateway, hermes dashboard, cloudflared started
```

**Restart sau khi đổi config/code** (vd `git pull`, sửa `.env`): boot mode bỏ qua service đang chạy → muốn áp thay đổi phải restart:
```bash
sh ~/.termux/boot/boot.sh --restart   # kill gateway/dashboard/cloudflared rồi start lại (KHÔNG đụng sshd)
```

## 3. Tắt phantom-process killer (trên PC, qua adb)

```bash
# trên LAPTOP, phone cắm USB + USB debugging bật (xem SETUP-PHONE Bước 6)
bash ~/t0lab/assistants/hermes/install/persistence/adb-tweaks.sh
```
Giá trị có thể reset sau reboot lớn/cập nhật HyperOS → chạy lại khi thấy Termux bị kill nền.

---

## Kiểm tra sau reboot

1. **Reboot** phone, **mở khoá màn hình 1 lần** (FBE — xem SETUP-PHONE Bước 3d), đợi ~1 phút (đừng mở Termux).
2. Từ laptop: `ssh phone` → vào được shell **mà không cần** mở Termux/gõ `sshd` tay → ✓ boot.sh chạy.
3. `cat ~/.hermes/logs/boot.log` → thấy các dòng `started` của lần boot mới nhất (sshd, gateway, dashboard, cloudflared).
4. Nhắn **Telegram bot** → trả lời ✓. Mở `https://chat.timezlab.org` → login Access → dashboard ✓.

> Lưu ý FBE: có khoá màn hình thì boot.sh (và mọi service) **chỉ chạy sau lần mở khoá đầu tiên** hậu-reboot. NetBird tự lên cũng vậy. Xem SETUP-PHONE Bước 3d.
