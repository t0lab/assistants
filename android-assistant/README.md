# TimezAssistant

Android assistant app với wake word detection và persistent voice conversation. OpenClaw là một module optional — app phục vụ người dùng, không phụ thuộc vào OpenClaw.

**Status:** Phase 5 — chưa implement. T5.1–T5.5 có thể làm song song với Phase 2.

**Package:** `com.timezlab.assistant`
**Min SDK:** 26 (Android 8.0)
**Language:** Kotlin + Jetpack Compose

## Điểm khác biệt với Google Assistant

| Google Assistant | TimezAssistant |
|-----------------|----------------|
| Wake word → lệnh → ngủ | Wake word → conversation mode |
| User phải nói wake word lại | Tiếp tục nói trong cùng session |
| Single-turn | Multi-turn, OpenClaw giữ context |

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
    ├── OpenClawModule  ws://localhost:4000 (optional)
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

`modules/openclaw/` — OpenClaw Gateway connector (optional module):
- WebSocket tới `ws://localhost:4000` (on-phone Gateway) hoặc Tailscale URL
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

- Exec plan Phase 5: `../docs/exec-plans/active/timezassistant-platform.md`
- STT server: `../stt-server/README.md`
- Gateway: `../openclaw-gateway/termux/README.md`
