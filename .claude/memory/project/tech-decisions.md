---
name: tech-decisions
type: project
created: 2026-04-24
last-updated: 2026-04-24
---

# Key Technical Decisions

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
Phone self-contained. Node.js LTS qua Termux pkg.
Mcp.json paths: `/data/data/com.termux/files/home/...`
Port 4000, token auth.

## Root access: MCP via su -c (NOT gateway as root)
Gateway process user-level. MCP server (USE_ROOT=true) executes `subprocess.run(["su", "-c", cmd])`.
Rationale: prompt injection risk nếu gateway chạy as root.

## Device persistence: Magisk module
Scripts chạy post-boot với root. Không dùng Termux:Boot (ít reliable hơn Magisk service.sh).

## Android app STT pluggable
Interface `STTProvider` — switch provider qua SharedPreferences, không rebuild.
Sentence-boundary TTS streaming: bắt đầu đọc ngay khi câu đầu tiên đến.
