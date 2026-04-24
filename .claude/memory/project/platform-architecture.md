---
name: platform-architecture
type: project
created: 2026-04-24
last-updated: 2026-04-24
---

# TimezAssistant Platform Architecture

## Deployment topology

Phone (Redmi Note 11S, LineageOS + Magisk):
- OpenClaw Gateway in Termux (Node.js :4000)
- mcp-root Python MCP server (root tools via `su -c`)
- TimezAssistant Android app (Kotlin)
- Magisk modules: device-guard (battery/thermal), gateway-autostart (boot trigger)

Home server (RTX 3060 12GB):
- whisper-live Docker container (CUDA, large-v3-turbo, :9090)
- Accessible via Tailscale when phone is off home network

## Voice session flow

Wake word (Porcupine) → VoiceSessionService foreground → AudioRecord 16kHz → SileroVAD chunks → STTProvider → text → OpenClawModule ws://localhost:4000 → streaming response → TTSManager sentence-by-sentence → back to LISTENING

Exit: silence >8s | keyword "thoát"/"dừng lại" | nút End | pin <15%

## STT provider interface

Pluggable — user switches in Settings without rebuild:
- Default: SherpaOnnx Zipformer-vi on-device (~31MB, offline)
- Option: WhisperLive WebSocket to home server (better Vietnamese accuracy)

## Directory map

```
openclaw-gateway/termux/     Node.js OpenClaw + mcp.json for Termux paths
openclaw-gateway/workspace/  Agent workspace (AGENTS, SOUL, MEMORY) — shared
device/scripts/     battery-guard.sh, thermal-monitor.sh, wakelock-manager.sh
device/magisk-module/ Magisk installer for device safety + boot trigger
mcp-root/           Python MCP server with root tools
stt-server/         whisper-live Docker + CUDA config
android-assistant/  Kotlin app: com.timezlab.assistant
bak/openclaw-gateway-docker/ Old Docker deployment (archived, unused)
```
