# TimezAssistant

Android assistant app với wake word detection và persistent voice conversation. Hermes (gateway) là module optional — app phục vụ người dùng, không phụ thuộc cứng vào Hermes.

**Status:** Deferred (sau) — chưa implement. Triển khai sau khi Hermes ổn định (xem `../docs/exec-plans/active/hermes-pivot.md`).

**Package:** `com.timezlab.assistant`
**Min SDK:** 26 (Android 8.0)
**Language:** Kotlin + Jetpack Compose

## Điểm khác biệt với Google Assistant

| Google Assistant | TimezAssistant |
|-----------------|----------------|
| Wake word → lệnh → ngủ | Wake word → conversation mode |
| User phải nói wake word lại | Tiếp tục nói trong cùng session |
| Single-turn | Multi-turn, Hermes giữ context |

## Kiến trúc

```
WakeWordService (background, Porcupine)
    │ wake word detected
    ▼
VoiceSessionService (foreground)
    ├── AudioRecord 16kHz mono
    ├── SileroVAD  → detect end-of-turn
    ├── STTProvider (pluggable)
    │   ├── SherpaOnnxSTT  default, on-device ~31MB
    │   └── WhisperLiveSTT ws://homeserver:9090
    ├── HermesModule  → Hermes trên phone (optional)
    └── TTSManager  Android TextToSpeech (sentence streaming)
```

## STT Provider

Configurable trong Settings — không cần rebuild app:

| Provider | Model | Yêu cầu | Vietnamese |
|----------|-------|---------|-----------|
| SherpaOnnx | Zipformer-vi 30M int8 | Offline, ~31MB | Tốt |
| WhisperLive | large-v3-turbo | Home server + Tailscale | Rất tốt (~7% WER) |

## Voice Session States

```
IDLE → [wake word] → LISTENING → [silence 800ms] → PROCESSING
                        ↑                               │
                        └───────────── SPEAKING ←───────┘
                                          │
                          [silence 8s / "thoát" / nút End]
                                          ↓
                                        IDLE
```

## Modules

`modules/hermes/` — Hermes connector (optional module):
- Kết nối tới Hermes trên phone (Termux) qua API server/gateway của Hermes
- Gửi text, nhận streaming response
- Bật/tắt trong Settings

## Build

```bash
cd android-assistant
./gradlew assembleDebug
./gradlew installDebug
```

## Permissions

- `RECORD_AUDIO` — STT và wake word
- `FOREGROUND_SERVICE` — VoiceSessionService
- `SYSTEM_ALERT_WINDOW` — VoiceOverlayView floating
- `RECEIVE_BOOT_COMPLETED` — tự start WakeWordService sau reboot
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` — tránh bị Android kill

## Xem thêm

- Pivot/plan: `../docs/exec-plans/active/hermes-pivot.md` (Android app = sau)
- STT server: `../stt-server/README.md`
- Hermes setup: `../hermes/README.md`
