# Hermes Pivot — Reusable Hermes Agent setup trên Termux

**Status:** active
**Created:** 2026-05-29
**Owner:** liamlee

## Goal

Một thư mục `hermes/` version-controlled cho phép: clone (sparse) + 3 lệnh → Hermes Agent chạy ổn định trên điện thoại (Termux, HyperOS chưa-root), nối model qua LiteLLM proxy, với SOUL + skills + config phục hồi đầy đủ.

## Background

Dự án pivot từ OpenClaw sang Hermes Agent. Nhu cầu cốt lõi: **tái sử dụng / tái cài dễ** — commit skills + system prompt + setup lên GitHub. Thiết bị thực tế là **stock HyperOS, chưa root** (không phải LineageOS+root như docs cũ ghi) → mọi khả năng phụ thuộc root bị defer. Model chạy remote (LiteLLM, OpenAI-compatible); phone chỉ chạy harness.

Shape rationale ở 2 ADR: `docs/design-docs/hermes-agent-replaces-openclaw.md` (vì sao Hermes), `docs/design-docs/hermes-config-as-code.md` (vì sao config-as-code + symlink + sparse-checkout). Lệnh cài Termux đã verify trực tiếp từ `scripts/install.sh` và docs `getting-started/termux.md` của Hermes.

## Tasks

- [ ] T1 — Scaffold thư mục `hermes/` + `.gitignore` + README
  - Done when: tồn tại `hermes/home/`, `hermes/install/`, `hermes/.env.example`, `hermes/README.md`; `.gitignore` loại trừ `.env`, `*.db`, `home/memories/*` (giữ `.gitkeep`); README mô tả flow restore (sparse clone → bootstrap → link → fill .env → hermes).
  - Files: `hermes/README.md`, `hermes/.gitignore`, `hermes/home/memories/.gitkeep`

- [ ] T2 — `hermes/install/bootstrap.sh` cài Hermes trên Termux (idempotent)
  - Done when: script chạy lại không lỗi; cài `pkg` deps (git python clang rust make pkg-config libffi openssl nodejs ripgrep ffmpeg), set `ANDROID_API_LEVEL`, tạo swapfile nếu RAM<8GB, chạy `install.sh` upstream (hoặc manual venv + `pip install -e '.[termux]' -c constraints-termux.txt`); kết thúc gợi ý chạy `hermes doctor`. `bash bootstrap.sh --help` in usage.
  - Files: `hermes/install/bootstrap.sh`

- [ ] T3 — `hermes/home/config.yaml` cấu hình model LiteLLM (không secret)
  - Done when: `model.provider: custom`, `model.default: openai/Qwen/Qwen3.6-35B-A3B`, `model.base_url` trỏ LiteLLM proxy; không có api_key trong file; có placeholder `mcp_servers` (comment) cho mcp-root phase sau.
  - Files: `hermes/home/config.yaml`

- [ ] T4 — `hermes/.env.example` template secrets
  - Done when: liệt kê `OPENAI_API_KEY=` (LiteLLM) + comment hướng dẫn; tùy chọn `TELEGRAM_BOT_TOKEN=` cho gateway mode; không chứa key thật; nêu rõ "copy sang ~/.hermes/.env".
  - Files: `hermes/.env.example`

- [ ] T5 — `hermes/install/link-home.sh` symlink home assets vào `$HERMES_HOME`
  - Done when: symlink `SOUL.md`, `config.yaml`, `skills/` từ `hermes/home/` → `~/.hermes/`; KHÔNG đụng `.env`/`state.db`/`memories/`; idempotent (xóa link cũ trước khi tạo); in trạng thái link sau khi chạy.
  - Files: `hermes/install/link-home.sh`

- [ ] T6 — `hermes/home/SOUL.md` seed nhân cách (tiếng Việt)
  - Done when: file non-empty, chỉ chứa identity/style/avoid/defaults (KHÔNG path/port/rule project — những thứ đó thuộc AGENTS.md); ≤ ~40 dòng.
  - Files: `hermes/home/SOUL.md`

- [ ] T7 — Skill mẫu đầu tiên làm khuôn `hermes/home/skills/`
  - Done when: 1 skill hợp lệ (frontmatter `name/description/version` + section When to Use/Procedure/Pitfalls), ví dụ `tro-ly/tra-loi-tieng-viet` hoặc `device/device-status`; sau `link-home.sh` thì `hermes skills list` hiển thị nó.
  - Files: `hermes/home/skills/<category>/<skill>/SKILL.md`

- [ ] T8 — `hermes/install/persistence/` giữ Hermes sống trên HyperOS chưa-root
  - Done when: có script Termux:Boot khởi động (`termux-wake-lock` + `hermes gateway start` hoặc CLI), `adb-tweaks.sh` (tắt phantom-process killer qua adb, không root), và README liệt kê thao tác tay HyperOS (autostart, battery no-restriction, khóa recents).
  - Files: `hermes/install/persistence/boot.sh`, `hermes/install/persistence/adb-tweaks.sh`, `hermes/install/persistence/README.md`

- [ ] T9 — Docs sweep: OpenClaw→Hermes, LineageOS→HyperOS unrooted; archive code cũ
  - Done when: `CLAUDE.md`, `ARCHITECTURE.md`, `docs/DESIGN.md`, `AGENTS.md`, `.claude/memory/project/*` phản ánh Hermes + HyperOS-unrooted; `openclaw-gateway/` chuyển vào `bak/`; `grep -ri "openclaw\|lineageos"` chỉ còn hit lịch sử/cố ý (ADR, bak/, plan cũ đã annotate).
  - Files: `CLAUDE.md`, `ARCHITECTURE.md`, `docs/DESIGN.md`, `AGENTS.md`, `.claude/memory/project/*.md`, `bak/openclaw-gateway/`

## Decisions log

- 2026-05-29: Hermes thay OpenClaw. Xem `docs/design-docs/hermes-agent-replaces-openclaw.md`.
- 2026-05-29: Config-as-code + symlink + sparse-checkout (monorepo `hermes/`). Xem `docs/design-docs/hermes-config-as-code.md`.
- 2026-05-29: Model name ở `config.yaml`, không ở `.env` (Hermes không đọc `MODEL_NAME`).
- 2026-05-29: Persistence không-root qua Termux:Boot + adb phantom-killer tweak (thay Magisk service.sh vì máy chưa root).

## Blockers

None. (Lưu ý: T2/T5/T7/T8 có done-condition cần verify on-device — máy thật trong Termux. Phần soạn file/script làm được offline; verify chạy thật cần điện thoại.)

## Out of scope

- Điều khiển UI app / AccessibilityService, screenshot, điều khiển hồng ngoại (cần native app — defer).
- Đọc data app khác, nhận SMS / nghe gọi đến, screenshot im lặng (cần ROOT — blocked tới khi unlock bootloader).
- Unlock bootloader / root (quyết định riêng của người dùng).
- Voice / wake word / STT (P5 cũ — chưa động tới trong plan này).
- Self-host model trên RTX 3060 (đang dùng LiteLLM proxy).
