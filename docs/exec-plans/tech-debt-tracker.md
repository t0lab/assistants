# Tech Debt Tracker

Known technical debt và quirks. Agents grep file này — giữ flat và scannable.

---

## Magisk boot trigger dùng `am start` + `input text`

- **Where:** `device/magisk-module/service.sh` (planned, Phase 1)
- **Symptom:** Cách trigger Termux script từ Magisk service.sh là dùng `am start` để mở Termux rồi simulate keypress `input text`. Fragile — phụ thuộc vào Termux UI state.
- **Why deferred:** Termux:API và Termux:Boot là alternatives nhưng cần cài thêm app; Magisk `service.sh` chạy trước khi Android fully booted nên `am broadcast` không reliable ngay lập tức.
- **Trigger to fix:** Khi tìm được cách reliable hơn — ví dụ Termux:Boot chạy ổn trên LineageOS, hoặc Magisk module exec Termux trực tiếp qua `/data/data/com.termux/files/usr/bin/bash`.
- **Created:** 2026-04-24

---

## whisper-live WebSocket protocol chưa có error recovery

- **Where:** `android-assistant/.../WhisperLiveSTT.kt` (planned, Phase 5)
- **Symptom:** Nếu home server restart giữa chừng trong một voice session, WebSocket drop mà không có clean handoff sang SherpaOnnx.
- **Why deferred:** Phase 5 scope là basic connectivity; fallback mechanism phức tạp hơn.
- **Trigger to fix:** Khi WhisperLive implementation xong và stable — thêm `onFailure()` handler tự switch sang SherpaOnnx với user notification.
- **Created:** 2026-04-24

---

## SherpaOnnx model download blocking UI

- **Where:** `android-assistant/.../SherpaOnnxSTT.kt` (planned, Phase 5)
- **Symptom:** Lần đầu chạy app phải download ~31MB model. Nếu download fail hoặc slow, app bị stuck.
- **Why deferred:** Basic case trước, polish sau.
- **Trigger to fix:** Sau khi basic STT flow hoạt động — thêm progress dialog, retry logic, và pre-bundle model trong APK nếu size cho phép.
- **Created:** 2026-04-24
