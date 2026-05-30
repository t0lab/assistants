# Persistence — giữ Hermes/SSH sống trên HyperOS chưa-root

Máy chưa root → không có Magisk `service.sh`/systemd. Cách giữ tiến trình nền sống dùng 3 lớp, không cần root:

| Lớp | Công cụ | Chống điều gì |
|-----|---------|---------------|
| Boot tự chạy | **Termux:Boot** → `boot.sh` | reboot làm mất `sshd`, wake-lock |
| Không ngủ CPU | `termux-wake-lock` (trong `boot.sh`) | Doze giết tiến trình nền |
| Không bị OS dọn | thao tác tay HyperOS + `adb-tweaks.sh` | autostart/battery + phantom-process killer |

## File

- **`boot.sh`** — chạy lúc khởi động (qua Termux:Boot): wake-lock + `sshd` (+ tùy chọn `hermes gateway`).
- **`adb-tweaks.sh`** — chạy **trên PC** qua adb: tắt phantom-process killer (Android 12+/HyperOS hay giết tiến trình nền của Termux).

---

## 1. Thao tác tay HyperOS (làm 1 lần)

Đã mô tả ở [`../SETUP-PHONE.md`](../SETUP-PHONE.md) **Bước 2** — cần đủ:
- Battery → **No restrictions** cho Termux
- **Autostart ON** cho **Termux** *và* **Termux:Boot** (Boot bắt buộc, không có thì `boot.sh` không chạy)
- Tắt "Tạm dừng hoạt động ứng dụng nếu không dùng"
- Khóa (🔒) thẻ **Termux** trong Recent apps

## 1b. NetBird tự kết nối lúc boot (để SSH-sau-reboot chạy)

`boot.sh` bật `sshd` khi khởi động, NHƯNG IP `100.97.86.95` là của NetBird — VPN chưa lên thì laptop báo `No route to host` (phải mở app NetBird tay). Cho NetBird tự lên:

1. **Autostart + battery** cho app NetBird: Settings → Apps → Permissions → **Autostart → NetBird ON**; Battery → **No restrictions**.
2. **Always-on VPN**: Settings → **Kết nối & chia sẻ → VPN** → ⚙ cạnh **NetBird** → bật **Always-on VPN**. (Tùy chọn *Block connections without VPN* — chỉ bật nếu chấp nhận mất mạng khi NetBird sập.)
3. NetBird dashboard: gán **IP cố định** cho peer phone để `100.97.86.95` không đổi.

> Vài máy chỉ dựng VPN sau lần mở khóa màn hình đầu tiên hậu-boot. Lỗi ngay sau reboot → mở khóa 1 lần rồi thử lại.

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
sh ~/.termux/boot/boot.sh      # chạy thử tay
cat ~/.hermes/logs/boot.log    # phải thấy wake-lock + sshd started
```

## 3. Tắt phantom-process killer (trên PC, qua adb)

```bash
# trên LAPTOP, phone cắm USB + USB debugging bật (xem SETUP-PHONE Bước 6)
bash ~/t0lab/assistants/hermes/install/persistence/adb-tweaks.sh
```
Giá trị có thể reset sau reboot lớn/cập nhật HyperOS → chạy lại khi thấy Termux bị kill nền.

---

## Kiểm tra sau reboot

1. **Reboot** phone, đợi ~1 phút (đừng mở Termux).
2. Từ laptop: `ssh phone` → vào được shell **mà không cần** mở Termux/gõ `sshd` tay → ✓ boot.sh chạy.
3. Trên phone (hoặc qua ssh): `cat ~/.hermes/logs/boot.log` → có dòng `wake-lock acquired` + `sshd started` của lần boot mới nhất.

## Gateway always-on (sau này)

`boot.sh` có sẵn block `hermes gateway start` (đang comment). Khi nào cấu hình transport (vd `TELEGRAM_BOT_TOKEN` trong `~/.hermes/.env` + `hermes gateway setup`), bỏ comment block đó → agent chạy nền 24/7, trả lời qua Telegram kể cả khi không mở TUI.
