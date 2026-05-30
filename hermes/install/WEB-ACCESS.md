# Web dashboard qua domain (Cloudflare Tunnel + Access)

Truy cập web UI của Hermes (chat + config) từ bất kỳ đâu qua `https://chat.timezlab.org`, gác bằng Cloudflare Access (đăng nhập email). Verified on-device 2026-05-31.

## Kiến trúc

```
Internet → Cloudflare edge (chat.timezlab.org)
         → Cloudflare Access (chặn theo email, OTP)
         → cloudflared (CHẠY TRÊN PHONE, nối outbound, không mở port)
         → hermes dashboard  (127.0.0.1/0.0.0.0:9119 trên phone)
```

Vì sao từng mảnh như vậy (đừng đổi nếu chưa hiểu — đều là bài học trả giá):

- **cloudflared phải chạy TRÊN PHONE**, không phải home server. WS handler của dashboard yêu cầu *client kết nối là loopback* (`_ws_client_is_allowed`). cloudflared-on-phone nối từ `127.0.0.1` ✓; chạy ở máy khác (qua NetBird) → client là IP NetBird → **WS bị chặn**.
- **dashboard chạy `--host 0.0.0.0 --insecure`.** WS handler còn kiểm **Origin** = đúng host đã bind (`_ws_host_origin_is_allowed`). Bind loopback chỉ nhận Origin `localhost`; browser gửi `Origin: chat.timezlab.org` mà cloudflared **không override được Origin** → WS fail. Bind `0.0.0.0` làm guard chấp nhận mọi Origin. `--insecure` là điều kiện để bind non-loopback.
- **`--insecure` = tắt auth riêng của dashboard** ⇒ **Cloudflare Access là lớp bảo vệ DUY NHẤT** ở public. Máy có tool `terminal`/`code_execution` → không Access = RCE cho người lạ. Access **bắt buộc**, không phải tuỳ chọn.
- Hệ quả: dashboard cũng lộ trên **NetBird** (`100.97.86.95:9119`) không auth. NetBird là mạng riêng của bạn → rủi ro nội bộ thấp, nhưng nhớ điều này.

## Setup (1 lần)

### 1. Cài deps trên phone
```bash
cd ~/.hermes/hermes-agent && source venv/bin/activate
pip install -e '.[web,pty]' -c constraints-termux.txt   # web UI + PTY cho tab Chat
pkg install cloudflared -y                               # tunnel
```
Chạy dashboard tay 1 lần để build frontend (npm, vài phút):
```bash
hermes dashboard --tui --host 0.0.0.0 --insecure --no-open
```

### 2. Cloudflare Tunnel (Zero Trust → Networks → Tunnels)

> Video hướng dẫn tạo tunnel (theo dõi từ ~5:40): https://www.youtube.com/watch?v=FBNo42bhozw&t=340s — *lưu ý: video không chỉ phần giới hạn user; xem mục 3 (Access policy → Include Emails) bên dưới.*

- Create tunnel → Cloudflared → lấy **token** → bỏ vào `~/.hermes/.env`: `CLOUDFLARE_TUNNEL_TOKEN=eyJ...`
- **Public Hostname:** `chat` . `timezlab.org` → Service **HTTP** `localhost:9119`.
  - Với `--insecure` thì **KHÔNG cần** "HTTP Host Header = localhost" (bind 0.0.0.0 nhận mọi Host).
  - Service trỏ `localhost:9119` (vì cloudflared ở trên phone). **Đừng** trỏ IP NetBird `100.97.86.95` — sẽ dính cảnh báo CGNAT/device-profile và hỏng WS.

### 3. Cloudflare Access (Zero Trust → Access → Applications)
- Add → **Self-hosted** → domain `chat.timezlab.org`, path `/`.
- **Policy:** Action **Allow**, **Include → Emails → email của bạn**. (Include là OR; chỉ email trong danh sách qua được.)
- Login method: **One-time PIN** (Settings → Authentication; mặc định bật) → đăng nhập bằng mã gửi qua email, không cần IdP.
- ⚠️ **Sửa policy không tự áp dụng vào app** — phải **xoá policy rồi add lại** thì app mới nhận. (CF quirk, đã gặp.)
- ⚠️ Đừng để sót policy **"Everyone"** — Access OR các policy, 1 policy mở là ai cũng vào.

### 4. Chạy
Tay (test): `hermes dashboard --tui --host 0.0.0.0 --insecure --no-open` + `cloudflared tunnel run --token <TOKEN>`.
Tự động sau reboot: xem `persistence/README.md` (đã có trong `boot.sh`).

→ Mở `https://chat.timezlab.org` (ẩn danh để test): hiện trang login Access → email bạn → OTP → vào dashboard; tab **Chat** + **Config** chạy.

## Cách kín hơn (không cần --insecure / không domain): SSH tunnel
```bash
ssh -L 9119:127.0.0.1:9119 phone     # laptop
# browser: http://localhost:9119
```
Qua SSH thì Origin = localhost → WS pass hết, dashboard giữ nguyên auth, không lộ ra ngoài. Thiếu mỗi cái domain public.

## Bảng lỗi đã gặp (symptom → cause → fix)

| Triệu chứng | Nguyên nhân | Fix |
|-------------|-------------|-----|
| `400 Invalid Host header` | bind loopback chỉ nhận Host=localhost | `--host 0.0.0.0 --insecure` (hoặc CF "HTTP Host Header=localhost") |
| Cảnh báo CGNAT / device profile | Service trỏ IP NetBird `100.64.x` | Service = `localhost:9119` (cloudflared ở trên phone) |
| API chậm/treo/duplicate, **524** | vòng lặp lazy-install `discord.py[voice]`/`brotlicffi` (C-ext fail trên Termux) chặn request | `security.allow_lazy_installs: false` trong config.yaml |
| WS `/api/ws,/events,/pty` failed | WS Origin-guard chỉ nhận Origin=bound host | `--host 0.0.0.0` (guard nhận mọi Origin); cloudflared phải ở **trên phone** |
| Access vẫn cho vào | sửa policy không áp / còn policy Everyone / session cache | xoá+add lại policy; xoá Everyone; test ẩn danh |
