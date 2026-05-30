# Chuẩn bị môi trường điện thoại (trước khi cài Hermes)

Hướng dẫn thao tác tay trên **Redmi Note 11S** (codename `fleur`, Helio G96 = **arm64-v8a**, HyperOS, **chưa root**) để dựng môi trường Termux sạch. Sau khi xong file này, chạy `bootstrap.sh` để cài chính Hermes.

> ℹ️ **RAM:** máy ~8GB + HyperOS có sẵn ~6GB zram swap → cài Hermes hầu như không OOM. Tự tạo swapfile thì cần root (không cần). Xem [Bước 5](#bước-5--cài-build-deps).
>
> Liên quan: exec plan `../../docs/exec-plans/active/hermes-pivot.md` (T2 bootstrap, T8 persistence).

---

## Bước 1 — Cài Termux + addon (đúng nguồn)

**KHÔNG cài từ Play Store** (bản đó ngừng cập nhật, lỗi). Tải từ **GitHub Releases**. Cả 3 app `+github` ký **cùng một khóa** → cài chung thì addon nhận nhau; đừng trộn nguồn (F-Droid / Play Store).

| App | Version (checked 2026-05-30) | Tải (arm64-v8a) |
|-----|------------------------------|-----------------|
| **Termux** | `v0.118.3` (2025-05-22) | https://github.com/termux/termux-app/releases/download/v0.118.3/termux-app_v0.118.3%2Bgithub-debug_arm64-v8a.apk |
| **Termux:Boot** | `v0.8.1` (2024-06-22) | https://github.com/termux/termux-boot/releases/download/v0.8.1/termux-boot-app_v0.8.1%2Bgithub.debug.apk |
| **Termux:API** | `v0.53.0` (2025-09-01) | https://github.com/termux/termux-api/releases/download/v0.53.0/termux-api-app_v0.53.0%2Bgithub.debug.apk |

Trang "latest" để kiểm version mới hơn về sau:
- Termux — https://github.com/termux/termux-app/releases/latest
- Termux:Boot — https://github.com/termux/termux-boot/releases/latest
- Termux:API — https://github.com/termux/termux-api/releases/latest

**Lưu ý cài:**
- Termux:Boot và Termux:API chỉ có 1 file đa kiến trúc — tải thẳng, không chọn ABI.
- Tải nhầm biến thể Termux → dùng `...universal.apk` (chạy mọi máy, nặng hơn).
- HyperOS chặn APK lạ → khi bấm cài, bật **"Install unknown apps"** cho trình duyệt/file manager đang dùng.
- **Thứ tự:** cài Termux trước → mở 1 lần cho nó bung gói cơ sở → rồi cài Termux:Boot và Termux:API.

---

## Bước 2 — HyperOS: chặn việc kill Termux + cấp quyền (thao tác tay)

Vừa cài 3 app xong thì chỉnh OS luôn. HyperOS dọn app nền rất hăng — không chỉnh thì Termux chết giữa chừng. Vào **Settings**:

- **Battery saver → No restrictions** (Không giới hạn): Settings → Apps → Manage apps → Termux → Battery saver
- **Autostart → ON**: Settings → Apps → **Permissions → Autostart** → (list tất cả app) → Termux. 🇻🇳 *Ứng dụng → Quyền → Tự khởi động*. **Lưu ý:** "Tự khởi động" là mục **ngang hàng** với "Quyền" — KHÔNG nằm trong trang quyền của riêng app. Cũng vào được qua app **Security / Bảo mật → Quyền → Tự khởi động**
- **Tắt "Tạm dừng hoạt động ứng dụng nếu không dùng"** cho Termux (trong trang quyền của app) — để HyperOS không thu hồi quyền/treo app khi lâu không mở
- Mở **Recent apps** → giữ (🔒 lock) thẻ **Termux** (chỉ Termux cần — `sshd`/Hermes chạy nền trong đây)
- **Autostart** bật cho cả **Termux:Boot** (bắt buộc — để chạy script lúc boot) và **Termux:API**. Hai app này **KHÔNG cần** lock recents: Termux:Boot chỉ chạy 1 lần lúc boot rồi tắt; Termux:API chỉ được gọi khi script chạy lệnh `termux-*`
- **Settings → About phone** → bấm "HyperOS version" 7 lần → bật **Developer options** (cần cho adb ở [Bước 6](#bước-6--tắt-phantom-process-killer))

### Quyền khác (Other permissions) — cấp tối thiểu, đừng bật bừa

Mở trang từng app → **Other permissions / Quyền khác**:

- **Termux** (app chạy nền lâu dài) — nên bật: **Start in background / Khởi động trong nền** và **Display pop-up while running in background / Hiện pop-up khi chạy nền** → giúp MIUI bớt kill và cho phép hoạt động từ nền. Các quyền còn lại (đổi WiFi, hiện trên màn khóa…) **không cần** cho sshd/Hermes.
- **Termux:API** — **không cấp full sẵn**. Cấp **theo nhu cầu** khi dùng: SMS / Điện thoại / Mic / Camera / Vị trí chỉ bật khi chạy lệnh `termux-*` tương ứng (Android tự hỏi lúc đó). **Đổi WiFi** chỉ cần nếu dùng `termux-wifi-*` — Hermes core không cần.
- **Termux:Boot** — chỉ cần **Autostart** (đã bật ở trên), không cần quyền khác.

---

## Bước 3 — Cài NetBird + bật SSH (điều khiển từ laptop)

Làm SSH sớm để các bước sau **copy/dán lệnh từ laptop** cho thoải mái, khỏi gõ trên bàn phím phone. NetBird tạo mạng overlay riêng (IP dải `100.64.0.0/10`) để laptop nối thẳng tới phone dù khác mạng.

**3a. Cài app NetBird trên phone**
- Play Store: tìm "NetBird"; hoặc GitHub: https://github.com/netbirdio/android-client/releases
- Đăng nhập đúng management server của bạn → bấm **Connect**.
- Mở app xem IP NetBird cấp cho phone. Nếu **khác** `100.97.86.95` → sửa `HostName` trong `~/.ssh/config` (mục 3c) cho khớp — hoặc gán cố định IP cho peer này trong NetBird dashboard để khỏi đổi.

**3b. Bật SSH server trong Termux** (mở Termux, chạy):
```bash
pkg update -y             # Termux mới tinh: refresh repo trước (Bước 4 sẽ upgrade đầy đủ)
pkg install openssh -y
passwd            # đặt mật khẩu login (gõ 2 lần, ký tự không hiện)
sshd              # khởi động sshd
```
> Termux sshd nghe sẵn **cổng 8022** — đúng với `Port 8022` trong config. Không dùng được port 22 (cần root).
> sshd **không tự chạy lại sau reboot** — tạm thời mở lại bằng `sshd` trong Termux. Tự động lúc boot: cài [`persistence/boot.sh`](persistence/README.md) qua Termux:Boot.

**3c. Trên laptop** — thêm vào `~/.ssh/config`:
```sshconfig
Host phone
    HostName 100.97.86.95   # đổi nếu NetBird cấp IP khác
    Port 8022
```
Kết nối: `ssh phone` → nhập mật khẩu vừa đặt. (Sau nên đổi sang SSH key để khỏi nhập mật khẩu mỗi lần.)

> **Không cần dòng `User`:** Termux chỉ có 1 user (app uid `u0_aXXX` do Android cấp, không đổi tên được) và sshd **bỏ qua username** khi xác thực → bỏ trống thì `ssh` dùng tên đăng nhập của laptop vẫn vào được. Muốn ép thì thêm `User <tên-bất-kỳ>` cũng chạy.

---

## Bước 4 — Khởi tạo Termux lần đầu

Có thể chạy ngay trên phone, hoặc **qua SSH từ laptop** (`ssh phone`):

```bash
pkg update && pkg upgrade -y  # cập nhật danh sách + nâng cấp gói
termux-setup-storage          # (tùy chọn) cấp quyền đọc /sdcard — Hermes không bắt buộc
```

> `termux-setup-storage` bật popup xin quyền → nên chạy khi **mở app Termux trên máy** (qua SSH có thể không hiện dialog). Hermes chạy trong `~` nên không cần /sdcard — bước này optional.

Tải gói chậm/timeout → đổi mirror rồi `pkg update` lại:

```bash
termux-change-repo            # chọn mirror gần (Singapore/Asia)
```

---

## Bước 5 — Cài build deps

Bộ công cụ build (verify từ docs Termux của Hermes) — cần sẵn cho bước cài Hermes về sau:

```bash
pkg install -y git python clang rust make pkg-config libffi openssl nodejs ripgrep ffmpeg
```

> **RAM ~8GB + HyperOS sẵn ~6GB zram swap** → build/cài hầu như không OOM (tự `swapon` thì cần root, nhưng không cần). `install.sh` còn dùng **prebuilt wheels** (`constraints-termux.txt`) thay vì compile. Nếu RAM trống thấp: reboot + đóng app nền cho chắc.
> Bạn **KHÔNG** tự gõ `pip install` — `install.sh` lo (xem bước cài Hermes).

---

## Bước 6 — Tắt phantom-process killer

Android 12+/HyperOS tự giết tiến trình nền của Termux → **bắt buộc tắt**, không thì `sshd`/Hermes chạy nền sẽ bị kill giữa chừng. Làm qua **adb** (không root).

**6a. Cài adb trên PC** (nếu chưa có)
- Tải **Android SDK Platform-Tools** → giải nén → thêm thư mục `platform-tools` vào **PATH** → mở terminal mới → `adb version` để kiểm.
  - Windows: https://dl.google.com/android/repository/platform-tools-latest-windows.zip (hoặc `winget install Google.PlatformTools`)
  - macOS/Linux: `brew install android-platform-tools` / gói `android-tools` của distro.

**6b. Bật USB debugging + kết nối**
- Phone → **Developer options → bật `USB debugging`** (🇻🇳 Gỡ lỗi USB). (Developer options đã mở ở Bước 2.)
- Cắm cáp USB (cáp truyền **data**, không phải sạc-only) → kéo thông báo USB → chọn **File transfer / MTP**.
- PC chạy `adb devices` → trên phone bấm **Allow** ở popup *"Allow USB debugging?"* (tick *Always allow*).
- Phải thấy `<serial>  device`. Chẩn đoán: `unauthorized` = chưa bấm Allow (thử `adb kill-server` rồi chạy lại); **trống** = sai cáp / chưa bật USB debugging / đang charging-only.

**6c. Tắt phantom-killer**
```bash
adb shell "/system/bin/device_config set_sync_disabled_for_tests persistent"
adb shell "/system/bin/device_config put activity_manager max_phantom_processes 2147483647"
adb shell settings put global settings_enable_monitor_phantom_procs false
```

Verify lệnh 2 đã ăn: `adb shell "/system/bin/device_config get activity_manager max_phantom_processes"` → mong `2147483647`.

> ⚠️ **MIUI/HyperOS gotcha:** lệnh 3 (`settings put global …`) hay báo `WRITE_SECURE_SETTINGS Permission denial`. Phải bật thêm **Developer options → `USB debugging (Security settings)`** (🇻🇳 *Gỡ lỗi USB (Cài đặt bảo mật)* — đòi **đăng nhập Mi account + lắp SIM**) rồi chạy lại. Ngại Mi account thì bỏ qua lệnh 3 — lệnh 2 (`max_phantom_processes` = max) đã là biện pháp chính; theo dõi xem Termux có bị kill không, bị thì mới bật Security settings.
> Giá trị có thể reset sau reboot → chạy lại bằng [`persistence/adb-tweaks.sh`](persistence/adb-tweaks.sh) (bản tự-động-hoá 3 lệnh này). Không có cáp: dùng **Wireless debugging** (`adb pair <IP>:<port>` rồi `adb connect <IP>:<port>`).

---

## Sanity check — xác nhận môi trường OK

```bash
python --version                 # mong: Python 3.11+
node --version
getprop ro.build.version.sdk     # API level (Hermes cần ANDROID_API_LEVEL)
free -m                          # RAM trống trước khi cài
git --version && rustc --version
```

Các lệnh chạy sạch → môi trường sẵn sàng. **Bước kế: cài Hermes** (`bootstrap.sh`: venv → `pip install -e '.[termux]'` → `hermes doctor`).

---

## 🔑 Lưu ý về secrets

API key (`OPENAI_API_KEY` của LiteLLM proxy) sống **trên điện thoại** ở `~/.hermes/.env` — **không** phải file `.env` trong repo. Repo chỉ giữ `.env.example` (template). **Đừng commit key thật lên GitHub.**
