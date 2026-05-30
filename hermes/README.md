# hermes/ — Hermes Agent config-as-code

Mọi thứ để dựng lại trợ lý Hermes trên một điện thoại mới: **system prompt + skills + config + script cài**. Version-control ở đây; **secrets thì không** (chỉ `.env.example`).

Brain là [Hermes Agent](https://github.com/NousResearch/hermes-agent) (Nous Research, MIT) chạy native trên Termux; model chạy **remote** qua LiteLLM proxy (phone chỉ chạy harness). Vì sao: xem `../docs/design-docs/hermes-agent-replaces-openclaw.md` và `../docs/design-docs/hermes-config-as-code.md`.

## Layout

```
hermes/
├── home/                  # symlink-vào ~/.hermes/ (config-as-code, COMMIT)
│   ├── SOUL.md            #   identity/style/defaults của trợ lý
│   ├── config.yaml        #   model (LiteLLM) + mcp_servers (placeholder) — KHÔNG secret
│   ├── skills/            #   skills drop-in (hermes skills list)
│   └── memories/          #   runtime của agent — .gitkeep, KHÔNG commit nội dung
├── install/
│   ├── SETUP-PHONE.md     # thao tác tay: Termux + HyperOS + SSH + adb (làm TRƯỚC)
│   ├── bootstrap.sh       # cài Hermes (pkg deps → clone → venv → pip)
│   └── link-home.sh       # symlink home/{SOUL,config.yaml,skills} → ~/.hermes/
└── .env.example           # template secrets → copy sang ~/.hermes/.env (KHÔNG commit)
```

`~/.hermes/` (`$HERMES_HOME`) là **runtime**: `bootstrap.sh` clone upstream vào `~/.hermes/hermes-agent`; `link-home.sh` gắn config từ repo vào đây; `.env`, `state.db`, `memories/` sinh ra lúc chạy và **không** version-control.

## Khôi phục trên máy mới

```bash
# 0. Chuẩn bị môi trường phone (1 lần, thao tác tay) — xem install/SETUP-PHONE.md:
#    Termux + addon, HyperOS chống-kill, NetBird+SSH, build deps, adb phantom-killer.

# 1. Lấy repo này về phone
git clone https://github.com/t0lab/assistants.git ~/t0lab/assistants
cd ~/t0lab/assistants/hermes

# 2. Cài Hermes (idempotent)
bash install/bootstrap.sh

# 3. Gắn config-as-code vào ~/.hermes/
bash install/link-home.sh

# 4. Điền secrets (key LiteLLM)
cp .env.example ~/.hermes/.env && nano ~/.hermes/.env   # điền OPENAI_API_KEY

# 5. Kiểm tra
hermes version && hermes doctor && hermes skills list
hermes                                                  # chạy TUI
```

> Sửa SOUL/skills/config: edit trong repo này (trên laptop) → `git push` → trên phone `git pull`. Symlink nên thay đổi có hiệu lực ngay, không cần chạy lại `link-home.sh`. **VS Code Remote-SSH KHÔNG chạy được trên Termux** (Android dùng bionic libc) → dùng luồng git pull, hoặc `micro`/`nano` qua `ssh phone`.

## Còn lại (xem `../docs/exec-plans/active/hermes-pivot.md`)

- **T7** — skill mẫu trong `home/skills/` (hiện mới có `.gitkeep`).
- **T8** — `install/persistence/` (Termux:Boot + adb-tweaks) giữ Hermes sống sau reboot.
