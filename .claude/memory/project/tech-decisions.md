---
name: tech-decisions
type: project
created: 2026-04-24
last-updated: 2026-05-29
---

# Key Technical Decisions

> **Pivot 2026-05-29:** OpenClaw → Hermes Agent; máy stock HyperOS chưa root. Mục Wake word/STT/VAD dưới đây thuộc phase Android app (sau).

## Agent: Hermes Agent (thay OpenClaw)
Nous Research `hermes-agent`, MIT, Python `.[termux]`. Termux native. Self-improving skills.
Xem `docs/design-docs/hermes-agent-replaces-openclaw.md`.

## Model: remote OpenAI-compatible (LiteLLM proxy)
Phone KHÔNG chạy LLM. `config.yaml`: `model.provider: custom`, `model.default`, `model.base_url`.
Key ở `~/.hermes/.env` (`OPENAI_API_KEY`). `MODEL_NAME` env KHÔNG được Hermes đọc.

## Config-as-code (reusability)
`hermes/home/` (SOUL.md, config.yaml, skills/) version-control, symlink vào `~/.hermes/`.
Secrets (`.env`) + runtime (`state.db`, `memories/`) KHÔNG commit. Sparse-checkout trên phone.
Xem `docs/design-docs/hermes-config-as-code.md`.

## Wake word: Picovoice Porcupine
Accuracy tốt nhất trên Android, offline, ~0.5% CPU, free 1 custom wake word.
Gradle: `ai.picovoice:porcupine-android:3.0.2`

## STT default: SherpaOnnx Zipformer-vi
Model: `sherpa-onnx-zipformer-vi-30M-int8-2026-02-09` (~31MB int8)
Streaming native (transducer), 6000h Vietnamese training, VAD bundled.
Helio G96 (Cortex-A76): practical for real-time chunked streaming.

## STT option: whisper-live (home server)
Image: `collabora/whisperlive:latest-cu124`
Model: `large-v3-turbo`, Vietnamese WER ~7%, RTF ~0.1x trên RTX 3060.
WebSocket protocol: binary PCM → JSON transcript.
Accessible qua Tailscale khi ra ngoài.

## VAD: Silero VAD
Bundled trong SherpaOnnx AAR. Threshold 0.5. Detect end-of-turn (silence 800ms sau speech).

## Gateway: Termux native (NOT Docker)
Phone self-contained. Hermes harness qua Termux pkg (Python), cài bằng `.[termux]`.
HERMES_HOME mặc định `~/.hermes` (`/data/data/com.termux/files/home/.hermes`).

## Root access: MCP via su -c — DEFERRED (máy chưa root)
Khi có root: Hermes user-level, MCP server (USE_ROOT=true) chạy `su -c`. Rationale: prompt injection risk nếu agent chạy as root. Hiện máy stock HyperOS chưa root → on hold.

## Device persistence (chưa root): Termux:Boot + wakelock
Termux:Boot chạy `boot.sh` (termux-wake-lock + hermes). adb tweak tắt phantom-process killer (không root). HyperOS: bật autostart + battery no-restriction tay. (Magisk service.sh chỉ dùng khi đã root.)

## Android app STT pluggable
Interface `STTProvider` — switch provider qua SharedPreferences, không rebuild.
Sentence-boundary TTS streaming: bắt đầu đọc ngay khi câu đầu tiên đến.
