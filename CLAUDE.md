# TimezLab Assistants

## Project

**Purpose:** Nền tảng trợ lý cá nhân tự host — **Hermes Agent** (Nous Research) chạy native trên Android phone qua Termux; model điều khiển qua endpoint OpenAI-compatible remote (LiteLLM proxy). Mục tiêu xa: điều khiển phone "như người thật" (UI app, SMS, call, camera, hồng ngoại) + Android voice app — **defer** tới khi Hermes ổn định và máy được root.

**Target device:** Redmi Note 11S 4G (Helio G96, codename `fleur`, có IR blaster) — **stock HyperOS, CHƯA root, CHƯA unlock bootloader** (tính tới 2026-05-29). Khả năng phụ thuộc root bị blocked tới khi unlock.
**Home server:** Linux + RTX 3060 12GB VRAM (whisper-live STT — KHÔNG host model agent)

## Stack

| Dir | Stack | Giai đoạn |
|-----|-------|-----------|
| `hermes/` | Hermes Agent (Python), Bash — config-as-code + Termux install | **active** (hermes-pivot) |
| `mcp-root/` | Python, MCP, `su -c` | on hold (cần root) |
| `device/` | Bash, Magisk module | on hold (cần root) |
| `stt-server/` | Docker, whisper-live, CUDA | sau (P4 cũ) |
| `android-assistant/` | Kotlin, Jetpack Compose, Gradle | sau (P5 cũ) |

## Architecture

```
Phone (Redmi Note 11S — stock HyperOS, chưa root):
└── Termux:
    └── Hermes Agent harness (Python, cài qua `.[termux]`)
        ├── Model: remote OpenAI-compatible (LiteLLM proxy) ← KHÔNG chạy LLM trên phone
        ├── Config: ~/.hermes/ (default profile) ← symlink hermes/home/ (SOUL.md=Jarvis, config.yaml, skills/)
        ├── Telegram: bot Jarvis (default — full tool, DM-only) + bot Friday (profile `friday` — group, least-privilege ← hermes/profiles/friday/)
        ├── Secrets: ~/.hermes/.env + ~/.hermes/profiles/friday/.env (token riêng mỗi bot — KHÔNG commit)
        └── MCP: mcp-root su -c (phase sau, khi đã root)
    └── Persistence: Termux:Boot + termux-wake-lock + adb phantom-killer tweak (không root)

Home Server (RTX 3060): whisper-live STT (phase sau)

Defer (cần root / native app):
└── Điều khiển UI app (AccessibilityService), screenshot, SMS/call nhận,
    camera, hồng ngoại (ConsumerIrManager), đọc data app khác, device safety
```

## Conventions

- Commits: Conventional Commits — invoke `git-conventional` skill before committing
- Plan before code — exec plan ở `docs/exec-plans/active/`
- Mỗi phase có done conditions rõ ràng (xem exec plan)
- Android app package: `com.timezlab.assistant`

## Key Decisions

- Agent brain: **Hermes Agent** (thay OpenClaw) — Termux native, MIT. Xem `docs/design-docs/hermes-agent-replaces-openclaw.md`
- Model: remote OpenAI-compatible (LiteLLM proxy). Tên model ở `config.yaml`, key ở `.env` (KHÔNG ở `MODEL_NAME` — Hermes không đọc)
- Config-as-code: SOUL.md / skills / config.yaml version-control trong `hermes/` (default `home/` + named `profiles/<name>/`), symlink vào `~/.hermes/`, secrets tách riêng. Xem `docs/design-docs/hermes-config-as-code.md`
- Telegram 2-profile: **Jarvis** (default, full tool + device, DM-only `TELEGRAM_ALLOWED_USERS`) + **Friday** (profile `friday`, bot group least-privilege — `disabled_toolsets` gỡ terminal/file/device…, `group_allowed_chats`+`require_mention`). Vì Hermes KHÔNG gate tool theo user → cô lập ở mức profile; token khác nhau mỗi bot. Xem `docs/design-docs/telegram-group-bot.md`
- Root: máy CHƯA root → "như người thật" (UI control, screenshot im lặng, SMS nhận, camera, hồng ngoại) **defer**. Khi có root: gateway KHÔNG chạy as root, dùng `su -c` qua MCP
- STT/voice (SherpaOnnx default, whisper-live option, session persistent): defer tới phase Android app
- Code OpenClaw cũ (Termux gateway + Docker) đã **xoá hẳn** — không archive (lịch sử ở git nếu cần)

## Memory

- User/feedback memory: `~/.claude/projects/-home-liamlee-t0lab-assistants/memory/`
- Project/reference memory: `.claude/memory/` (committed)

@.claude/memory/project.md
@.claude/memory/reference.md

