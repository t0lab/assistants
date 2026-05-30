# Cấu hình Hermes là code: version-control SOUL/skills/config, secrets tách riêng

**Status:** accepted
**Date:** 2026-05-29
**Deciders:** liamlee

## Context

Nhu cầu chính của người dùng: **tái sử dụng & tái cài dễ dàng** — commit skills + system prompt + setup lên GitHub để máy mới (hoặc sau wipe) restore trong vài phút. Hermes lưu toàn bộ asset cấu hình dưới dạng **file phẳng** trong `HERMES_HOME` (mặc định `~/.hermes`, override được qua env `HERMES_HOME`):

| File/Dir | Vai trò | Tính chất |
|---|---|---|
| `SOUL.md` | Identity / system prompt (slot #1, thay default identity) | Durable, người dùng viết |
| `skills/<cat>/<skill>/SKILL.md` | Procedural knowledge, thả-là-chạy (không cần đăng ký) | Durable; agent cũng tự tạo được |
| `config.yaml` | Model, mcp_servers, memory limits, approvals… | Durable, **không** secret |
| `memories/MEMORY.md`,`USER.md` | Agent tự ghi lúc chạy (2200/1375 ký tự) | Runtime, mutate liên tục |
| `.env` | API keys, bot tokens | **Secret** |
| `state.db` | SQLite sessions (FTS5) | Runtime |

## Decision

Duy trì một thư mục git-tracked **`hermes/`** trong monorepo này làm **source of truth** cho các asset durable của Hermes: `SOUL.md`, `config.yaml`, custom skills, hướng dẫn dạng `AGENTS.md`, và install scripts. Trên thiết bị, script `link-home.sh` **symlink** các file này vào `~/.hermes/`. Secrets (`.env`) và runtime (`state.db`, `memories/`) **nằm ngoài git**. Điện thoại dùng **git sparse-checkout** để chỉ kéo `hermes/` (không kéo cả monorepo).

Layout:
```
hermes/
├── home/{SOUL.md, config.yaml, skills/**, memories/.gitkeep}   # link vào $HERMES_HOME
├── .env.example                                                # template, key trống
├── install/{bootstrap.sh, link-home.sh, persistence/}
└── README.md
```
Restore = `git clone` (sparse `hermes/`) → `bootstrap.sh` → `link-home.sh` → điền `.env` → `hermes`.

## Alternatives considered

- **Trỏ thẳng `HERMES_HOME` vào repo dir** — rejected. Trộn runtime/secret với file tracked → `.gitignore` mong manh, dễ lỡ commit key.
- **Dùng `hermes export`/`import` (zip backup)** — rejected làm cơ chế chính. Blob khó diff trong git, không review PR được. Giữ làm backup ad-hoc.
- **Commit cả `memories/`** — rejected. Memory mutate liên tục (agent-managed, giới hạn ký tự) → churn vô nghĩa; có thể tái tạo.
- **Repo độc lập** — considered. Rejected để giữ monorepo một-nguồn; dùng sparse-checkout cho clone gọn trên phone.

## Consequences

**Better:**
- Toàn bộ setup (nhân cách + skills + cấu hình model) reproduce bằng clone + 3 lệnh.
- Asset diffable / review được qua PR; dùng cross-device.
- Secrets không bao giờ vào git.
- Skill do Hermes tự sinh có thể commit ngược lại repo để tái dùng.

**Worse:**
- Lớp symlink thêm 1 bước setup và 1 kiểu lỗi mới (link gãy).
- Mô hình "2 chỗ" (tracked vs runtime) phải nhớ.
- Skill/memory agent tự tạo sẽ drift khỏi repo nếu không commit định kỳ.
- Sparse-checkout thêm độ phức tạp git trên phone.

**Must now be true:**
- Chỉ asset durable được track: `hermes/home/SOUL.md`, `hermes/home/config.yaml`, `hermes/home/skills/**`, install scripts, AGENTS-equivalent.
- `.env`, `state.db`, `~/.hermes/memories/*` **không bao giờ** commit; `.gitignore` enforce; chỉ cung cấp `.env.example`.
- `config.yaml` **không** chứa secret (api_key ở `.env`, tham chiếu qua env).
- `SOUL.md` chỉ chứa identity/style; rule riêng project để ở `AGENTS.md` (đúng convention của Hermes).
- Restore phải đi qua: sparse clone `hermes/` → `bootstrap.sh` → `link-home.sh` → điền `.env` → `hermes`.

## Revisit if

Hermes đổi layout `HERMES_HOME` hoặc thêm git-sync first-class; HOẶC symlink tỏ ra quá mong manh trên Termux → chuyển sang copy-on-deploy.
