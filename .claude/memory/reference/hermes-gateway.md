---
name: hermes-gateway
type: reference
created: 2026-05-29
last-updated: 2026-05-29
---

# Hermes Agent — Termux Setup

Repo: github.com/NousResearch/hermes-agent (MIT, Python 3.11+, uv). Có Termux support chính thức.

## Install (Termux)
One-liner: `curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash`
(auto-detect Termux → thử `.[termux-all]` → `.[termux]` → core, dùng `constraints-termux.txt`)

⚠️ **DÙNG install.sh, ĐỪNG tự gọi pip.** Manual `pip install -e '.[termux]' -c constraints-termux.txt` **FAIL ở `psutil`** ("platform android is not supported") vì Python 3.13 trên Termux báo `sys.platform == 'android'`; psutil setup.py chưa nhận platform đó (psutil#2762). install.sh xử lý bằng `scripts/install_psutil_android.py` (prebuild psutil từ sdist + patch marker) TRƯỚC khi pip install. Nó còn lo: build toolchain (`pkg install`), venv, fallback extras `[termux-all]→[termux]→core`, symlink `hermes` vào PATH, tạo `~/.hermes/{.env,config.yaml,SOUL.md}` default nếu vắng + sync skill bundled vào `~/.hermes/skills/`.

Repo dùng `hermes/install/bootstrap.sh` (ủy quyền install.sh) + `link-home.sh` (gắn config-as-code TRƯỚC, để default không đè). RAM ~8GB + HyperOS sẵn ~6GB zram → hầu như không OOM (tự tạo swap cần root; không cần).
Skip trên Termux: voice (faster-whisper), browser/playwright, Docker, systemd (dùng nohup).

## Config layout (`$HERMES_HOME`, mặc định `~/.hermes`, override qua env `HERMES_HOME`)
- `SOUL.md` — identity/system prompt (slot #1, thay default identity) — COMMIT
- `skills/<cat>/<skill>/SKILL.md` — drop-in, không cần đăng ký — COMMIT
- `config.yaml` — model/mcp_servers/memory (không secret) — COMMIT
- `memories/MEMORY.md`, `USER.md` — agent runtime (2200/1375 ký tự) — không commit
- `.env` — secrets (`OPENAI_API_KEY`…) — KHÔNG commit
- `state.db` — SQLite sessions (FTS5) — không commit

## Model config (LiteLLM proxy, OpenAI-compatible)
`config.yaml`:
```
model:
  provider: custom
  default: openai/Qwen/Qwen3.6-35B-A3B
  base_url: https://litellm-horseai.everlearners.io/v1   # LiteLLM thường cần /v1
  # context_length: 131072  # set nếu proxy không expose /v1/models
```
`.env`: `OPENAI_API_KEY=...`  (lưu ý: `MODEL_NAME`/`LLM_MODEL` env KHÔNG được Hermes đọc)

## Run
`hermes` (CLI/TUI) | `hermes gateway setup && hermes gateway start` (always-on: Telegram/Signal…)
`hermes skills list` | `hermes model` | `hermes config set K V` | `hermes doctor`

## Migrate từ OpenClaw
`hermes claw migrate` (import SOUL/MEMORY/skills/model/MCP từ `~/.openclaw`). Flags: `--source <path>`, `--dry-run`, `--migrate-secrets`.

## Docs
- https://hermes-agent.nousresearch.com/docs/getting-started/termux
- https://hermes-agent.nousresearch.com/docs/reference/environment-variables
- https://hermes-agent.nousresearch.com/docs/guides/use-soul-with-hermes
- https://hermes-agent.nousresearch.com/docs/guides/work-with-skills
