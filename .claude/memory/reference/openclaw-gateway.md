---
name: openclaw-gateway
type: reference
created: 2026-04-24
last-updated: 2026-04-24
---

# OpenClaw Gateway — Termux Setup

## Install
```bash
pkg install nodejs-lts python3 git curl
npm install -g openclaw
```

## Key paths (Termux)
- Home: `/data/data/com.termux/files/home/`
- MCP config: `~/.openclaw/mcp.json` (hoặc path trong start script)
- Workspace: `~/openclaw-gateway/workspace/`
- State: `~/openclaw-gateway/state/`

## Port + auth
Default port: 4000
Auth: token mode — `OPENCLAW_GATEWAY_TOKEN` env var

## MCP servers (Termux)
- filesystem: `npx @modelcontextprotocol/server-filesystem <workspace-path>`
- sqlite: `python3 -m mcp_server_sqlite --db-path <path>`
- android-root: `python3 ~/mcp-root/server.py` với `USE_ROOT=true`

## whisper-live (home server)
Image: `collabora/whisperlive:latest-cu124`
Port: 9090 WebSocket
Model: `large-v3-turbo`, language: `vi`, device: `cuda`
Accessible qua Tailscale IP khi phone off home network

## Docs
- https://docs.openclaw.ai/start/getting-started
- https://docs.openclaw.ai/install/docker
