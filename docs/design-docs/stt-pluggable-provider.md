# STT Provider là pluggable interface, không hardcode implementation

**Status:** accepted
**Date:** 2026-04-24

## Context

App cần STT cho voice conversation. Hai options với trade-off khác nhau: SherpaOnnx (on-device, offline, ~31MB, tiếng Việt tốt) và whisper-live trên home server (accuracy cao hơn, ~7% WER, cần internet/Tailscale). User có thể ở cả hai điều kiện.

Redmi Note 11S (Helio G96) không đủ mạnh để chạy Whisper large real-time — cần home server RTX 3060 cho option đó.

## Decision

`STTProvider` là Kotlin interface. `SherpaOnnxSTT` và `WhisperLiveSTT` implement interface này. User chọn provider trong Settings (SharedPreferences). `VoiceSessionService` nhận provider qua constructor injection, không biết cụ thể là implementation nào.

## Alternatives considered

- **Chỉ dùng SherpaOnnx** — rejected. Accuracy tiếng Việt với model 30M int8 đủ dùng nhưng không tốt bằng large-v3-turbo. User có home server RTX 3060 nên không bỏ phí.
- **Chỉ dùng WhisperLive** — rejected. Khi không có internet hoặc home server offline, app mất khả năng STT hoàn toàn.
- **Hardcode cả hai, switch bằng flag compile-time** — rejected. Cần rebuild app để đổi provider; user không thể test cả hai.

## Consequences

**Better:**
- User switch STT provider trong Settings không cần rebuild
- Dễ thêm provider mới (Google Cloud STT, Deepgram) trong tương lai — chỉ implement interface
- Testing độc lập cho từng provider
- Graceful fallback: nếu WhisperLive không kết nối được, hiển thị lỗi rõ ràng và suggest switch sang SherpaOnnx

**Worse:**
- Thêm abstraction layer — code nhiều hơn một chút
- `isAvailable()` phải check network cho WhisperLive, check model file cho SherpaOnnx

**Must now be true:**
- `VoiceSessionService` chỉ phụ thuộc vào `STTProvider` interface, không import `SherpaOnnxSTT` hay `WhisperLiveSTT` trực tiếp
- Provider được inject qua factory/DI, không khởi tạo inline trong service
- Mỗi provider tự quản lý lifecycle (connect/disconnect, model load/unload)
- Settings key: `pref_stt_provider` với values `sherpa_onnx` | `whisper_live`

## Revisit if

Có thêm provider thứ 3 cần tích hợp, hoặc interface cần thay đổi lớn (ví dụ: thêm speaker diarization) → xem xét plugin architecture thay vì enum-style selection.
