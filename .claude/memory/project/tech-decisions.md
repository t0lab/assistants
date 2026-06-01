---
name: tech-decisions
type: project
created: 2026-04-24
last-updated: 2026-06-01
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
Termux là cái giá của north-star "điều khiển phone" (Docker không chạy trên Android, và Docker trên home-server không chạm phone). Revisit-if của ADR chỉ kích hoạt khi RAM<4GB/thermal — máy ~8GB nên giữ Termux.

## Telegram: 2 profile (Jarvis owner / Friday group) — KHÔNG phải 1 bot 2 lớp
- **default** (`~/.hermes/`) — agent **Jarvis**, full tool + device MCP, **DM-only** (`TELEGRAM_ALLOWED_USERS` = owner).
- **`friday`** (`~/.hermes/profiles/friday/`) — agent **Friday**, bot group least-privilege: `agent.disabled_toolsets` gỡ terminal/code_execution/file/memory/messaging/device…, KHÔNG khai `mcp_servers`; `group_allowed_chats` + `require_mention: true`.

**Why:** Hermes KHÔNG gate tool theo user; approval đẩy về chính người trigger (tự duyệt được) → rule prompt (SOUL) KHÔNG phải security boundary. Tool nhạy cảm chỉ cô lập được ở **mức profile**. Token Telegram phải KHÁC nhau mỗi profile (Telegram 1 getUpdates/token; Hermes tự chặn trùng).
**How to apply:** Thêm bot least-privilege khác → tạo profile mới dưới `hermes/profiles/<name>/`, KHÔNG nới quyền bot group. Allowlist toolset set on-device `hermes -p <name> tools` (không có allowlist native → **re-audit khi nâng cấp Hermes**). Cron có thể escalate qua `enabled_toolsets` per-job → verify `disabled_toolsets` là sàn cứng.
Config-as-code: `hermes/profiles/<name>/` symlink qua `link-home.sh` (loop); `boot.sh` tự start `hermes -p <name> gateway` cho profile có `TELEGRAM_BOT_TOKEN`.
Naming: theme Iron Man — **Jarvis** (owner) / **Friday** (group) / Edith (nếu cần); username `@timezlab_<agent>_bot`.
ADR: `docs/design-docs/telegram-group-bot.md`; setup: `hermes/install/TELEGRAM-GROUP.md`; plan: `docs/exec-plans/active/telegram-group-bot.md`.

## Root access: MCP via su -c — DEFERRED (máy chưa root)
Khi có root: Hermes user-level, MCP server (USE_ROOT=true) chạy `su -c`. Rationale: prompt injection risk nếu agent chạy as root. Hiện máy stock HyperOS chưa root → on hold.

## Device persistence (chưa root): Termux:Boot + wakelock
Termux:Boot chạy `boot.sh` (termux-wake-lock + hermes). adb tweak tắt phantom-process killer (không root). HyperOS: bật autostart + battery no-restriction tay. (Magisk service.sh chỉ dùng khi đã root.)

## Android app STT pluggable
Interface `STTProvider` — switch provider qua SharedPreferences, không rebuild.
Sentence-boundary TTS streaming: bắt đầu đọc ngay khi câu đầu tiên đến.
