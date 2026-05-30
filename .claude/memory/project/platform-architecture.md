---
name: platform-architecture
type: project
created: 2026-04-24
last-updated: 2026-05-29
---

# TimezAssistant Platform Architecture

> **Pivot 2026-05-29:** OpenClaw → Hermes Agent; thiết bị là stock HyperOS **chưa root** (không phải LineageOS+Magisk). Phần Android voice + root đều defer. Xem `docs/design-docs/hermes-agent-replaces-openclaw.md`.

## Deployment topology (current)

Phone (Redmi Note 11S, **stock HyperOS, chưa root**):
- Hermes Agent harness in Termux (Python, `.[termux]`)
- Model: remote OpenAI-compatible endpoint (LiteLLM proxy) — KHÔNG chạy LLM trên phone
- Config-as-code: `~/.hermes/` symlink từ repo `hermes/home/` (SOUL.md, config.yaml, skills/); secrets ở `~/.hermes/.env` (không commit)
- Persistence: Termux:Boot + termux-wake-lock + adb phantom-killer tweak (không root)

Deferred (cần root / native app):
- mcp-root Python MCP (`su -c` root tools), device-guard Magisk module
- TimezAssistant Android app (voice), điều khiển UI/SMS/camera/hồng ngoại
- whisper-live STT trên home server (RTX 3060, Tailscale)

## Voice session flow (phase Android app, sau)

Wake word (Porcupine) → VoiceSessionService → AudioRecord 16kHz → SileroVAD → STTProvider → text → Hermes (qua ws/MCP) → streaming response → TTSManager → back to LISTENING

Exit: silence >8s | keyword "thoát"/"dừng lại" | nút End | pin <15%

## STT provider interface

Pluggable — user switches in Settings without rebuild:
- Default: SherpaOnnx Zipformer-vi on-device (~31MB, offline)
- Option: WhisperLive WebSocket to home server (better Vietnamese accuracy)

## Directory map

```
hermes/home/        SOUL.md, config.yaml, skills/ — symlink vào ~/.hermes/
hermes/install/     bootstrap.sh, link-home.sh, persistence/
mcp-root/           Python MCP server root tools — on hold (cần root)
device/             battery-guard.sh, thermal-monitor.sh, Magisk module — on hold (cần root)
stt-server/         whisper-live Docker + CUDA — sau
android-assistant/  Kotlin app: com.timezlab.assistant — sau
openclaw-gateway/   Cũ (OpenClaw) — deprecated, sẽ vào bak/
bak/openclaw-gateway-docker/ Old Docker deployment (archived, unused)
```
