---
name: platform-architecture
type: project
created: 2026-04-24
last-updated: 2026-06-01
---

# TimezAssistant Platform Architecture

> **Pivot 2026-05-29:** OpenClaw → Hermes Agent; thiết bị là stock HyperOS **chưa root** (không phải LineageOS+Magisk). Phần Android voice + root đều defer. Xem `docs/design-docs/hermes-agent-replaces-openclaw.md`.

## Deployment topology (current)

Phone (Redmi Note 11S, **stock HyperOS, chưa root**):
- Hermes Agent harness in Termux (Python, `.[termux]`)
- Model: remote OpenAI-compatible endpoint (LiteLLM proxy) — KHÔNG chạy LLM trên phone
- Config-as-code: `~/.hermes/` symlink từ repo `hermes/home/` (SOUL.md, config.yaml, skills/); secrets ở `~/.hermes/.env` (không commit)
- Telegram: 2 profile — **default** (agent **Jarvis**, full tool + device MCP, DM-only) + **`friday`** (agent **Friday**, bot group least-privilege, symlink từ `hermes/profiles/friday/`). Xem `docs/design-docs/telegram-group-bot.md`
- Persistence: Termux:Boot + termux-wake-lock + adb phantom-killer tweak (không root); `boot.sh` start gateway cho default + mỗi profile có token

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
hermes/home/        SOUL.md (Jarvis), config.yaml, skills/ — symlink vào ~/.hermes/ (default profile)
hermes/profiles/    named profile → ~/.hermes/profiles/<name>/ (vd friday — bot group Friday, least-privilege)
hermes/install/     bootstrap.sh, link-home.sh, persistence/, TELEGRAM-GROUP.md
mcp-root/           Python MCP server root tools — on hold (cần root)
device/             battery-guard.sh, thermal-monitor.sh, Magisk module — on hold (cần root)
stt-server/         whisper-live Docker + CUDA — sau
android-assistant/  Kotlin app: com.timezlab.assistant — sau
# (code OpenClaw cũ — Termux gateway + Docker — đã xoá hẳn 2026-05-30, không archive)
```
