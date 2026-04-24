# TimezLab Assistants

## Project

**Purpose:** Nền tảng trợ lý cá nhân tự host — OpenClaw Gateway chạy native trên Android phone (LineageOS + Magisk root), Android assistant app với wake word + persistent voice conversation, STT server on-premise.

**Target device:** Redmi Note 11S (Helio G96, LineageOS + Magisk root)
**Home server:** Linux + RTX 3060 12GB VRAM

## Stack

| Dir | Stack | Giai đoạn |
|-----|-------|-----------|
| `openclaw-gateway/termux/` | Node.js (OpenClaw), Bash | P2 |
| `device/` | Bash, Magisk module | P1 |
| `mcp-root/` | Python, MCP, ppadb | P3 |
| `stt-server/` | Docker, whisper-live, CUDA | P4 |
| `android-assistant/` | Kotlin, Jetpack Compose, Gradle | P5 |

## Architecture

```
Phone (LineageOS + Magisk):
├── Termux: OpenClaw Gateway (Node.js :4000) + mcp-root server
├── TimezAssistant app:
│   ├── WakeWordService (Porcupine, background)
│   ├── VoiceSessionService (persistent conversation loop)
│   │   ├── STT: SherpaOnnx Zipformer-vi (default, on-device)
│   │   │    OR  WhisperLive ws://homeserver:9090 (settings)
│   │   ├── OpenClaw module → ws://localhost:4000
│   │   └── TTS: Android built-in TextToSpeech
│   └── Magisk: boot autostart + device safety scripts
└── Magisk module: battery-guard + thermal-monitor (root)

Home Server (RTX 3060):
└── stt-server/: whisper-live large-v3-turbo, CUDA, :9090
```

## Conventions

- Commits: Conventional Commits — invoke `git-conventional` skill before committing
- Plan before code — exec plan ở `docs/exec-plans/active/`
- Mỗi phase có done conditions rõ ràng (xem exec plan)
- Android app package: `com.timezlab.assistant`

## Key Decisions

- STT mặc định: SherpaOnnx Zipformer-vi (offline, on-device, ~31MB)
- STT option: whisper-live home server — configurable trong app Settings
- Voice session: persistent (không cần wake word lại sau mỗi lượt)
- Exit session: silence >8s | nói "thoát"/"dừng lại" | nhấn nút End
- Gateway KHÔNG chạy as root — MCP tools dùng `su -c` để exec root commands trên phone
- Docker setup cũ ở `bak/openclaw-gateway-docker/` (không dùng nữa)

## Memory

- User/feedback memory: `~/.claude/projects/-home-liamlee-t0lab-assistants/memory/`
- Project/reference memory: `.claude/memory/` (committed)

@.claude/memory/project.md
@.claude/memory/reference.md

