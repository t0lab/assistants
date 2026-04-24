# Gateway

OpenClaw Gateway deployment cho TimezAssistant platform.

## Subdirs

| Dir | Mô tả | Status |
|-----|-------|--------|
| `termux/` | Deploy native trên phone (LineageOS + Termux) | Phase 2 |
| `workspace/` | Agent workspace: AGENTS.md, SOUL, IDENTITY, MEMORY | Active |
| `state/` | Runtime state do OpenClaw quản lý | Active |
| `skills/` | OpenClaw skills | Active |

## Architecture

Gateway chạy trong Termux trên phone, không Docker. Phone self-contained — không cần server ngoài.

```
Termux:
├── openclaw gateway start  (port 4000)
└── mcp-root/server.py      (Python MCP, root tools via su -c)
```

## Workspace

`workspace/` chứa các tài liệu vận hành của agent:
- `AGENTS.md` — hướng dẫn hành vi cho OpenClaw agent
- `SOUL.md` — personality và giá trị cốt lõi
- `IDENTITY.md` — định danh agent
- `USER.md` — thông tin về người dùng
- `TOOLS.md` — tài liệu các tools/MCP servers

## Xem thêm

- Setup chi tiết: `termux/README.md`
- Exec plan: `../docs/exec-plans/active/timezassistant-platform.md` (Phase 2)
