#!/data/data/com.termux/files/usr/bin/sh
# Termux:Boot startup — chạy MỖI lần thiết bị khởi động.
# Mục tiêu: phone "cắm điện là chạy" trên HyperOS chưa-root. Tự bật:
#   - termux-wake-lock        : chặn CPU ngủ sâu giết tiến trình nền
#   - sshd (8022)             : SSH từ laptop sau reboot
#   - hermes gateway          : Telegram bot always-on (đọc ~/.hermes/.env)
#   - hermes dashboard        : web UI (chat + config); --host 0.0.0.0 --insecure để WS
#                               qua cloudflared chạy được — Cloudflare Access gác public
#   - cloudflared tunnel      : expose dashboard ra chat.timezlab.org (token ở .env)
#
# CÀI: cần app Termux:Boot + Autostart bật (xem ../SETUP-PHONE.md Bước 2), rồi:
#   mkdir -p ~/.termux/boot
#   ln -sf ~/t0lab/assistants/hermes/install/persistence/boot.sh ~/.termux/boot/boot.sh
#   chmod +x ~/t0lab/assistants/hermes/install/persistence/boot.sh
# Lần đầu nên chạy `hermes dashboard` tay 1 lần để nó build frontend (npm) xong.
# Chi tiết + bảo mật: persistence/README.md, ../WEB-ACCESS.md.
#
# Cách dùng:
#   sh boot.sh            — boot mode: start service nào CHƯA chạy (idempotent, không kill).
#   sh boot.sh --restart  — kill gateway/dashboard/cloudflared rồi start lại (KHÔNG đụng sshd).

# PATH tối thiểu của Termux (môi trường boot có thể chưa set)
PATH=/data/data/com.termux/files/usr/bin:/data/data/com.termux/files/usr/bin/applets
export PATH

# `hermes` trên PATH KHÔNG resolve được lúc boot (venv chưa active / wrapper kén env)
# → dùng entry-point tuyệt đối trong venv (shebang tự trỏ venv python). Fallback về PATH.
HERMES="$HOME/.hermes/hermes-agent/venv/bin/hermes"
[ -x "$HERMES" ] || HERMES="$(command -v hermes 2>/dev/null)"

ENV_FILE="$HOME/.hermes/.env"
LOG_DIR="$HOME/.hermes/logs"
mkdir -p "$LOG_DIR"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_DIR/boot.log"; }
log "boot.sh start (${1:-boot})"

# --restart: kill service do script quản (KHÔNG đụng sshd — tránh rớt phiên SSH), rồi start lại sạch.
if [ "${1:-}" = "--restart" ] || [ "${1:-}" = "restart" ]; then
  log "restart: killing gateway/dashboard/cloudflared"
  pkill -f 'hermes gateway'   2>/dev/null
  pkill -f 'hermes dashboard' 2>/dev/null
  pkill -x cloudflared        2>/dev/null
  command -v fuser >/dev/null 2>&1 && fuser -k 9119/tcp 2>/dev/null
  sleep 2
fi

# start_bg <pgrep-pattern> <logfile> <cmd...> — chạy nền nếu chưa chạy; xác nhận sống thật sau 2s
start_bg() {
  _pat="$1"; _log="$2"; shift 2
  if pgrep -f "$_pat" >/dev/null 2>&1; then log "[$_pat] already running"; return; fi
  nohup "$@" >> "$_log" 2>&1 &
  _pid=$!
  sleep 2
  if kill -0 "$_pid" 2>/dev/null; then
    log "[$_pat] started pid=$_pid"
  else
    log "[$_pat] FAILED (chết ngay — xem $_log)"
  fi
}

# wait_for_net — chờ có internet (Telegram/Cloudflare cần), tối đa ~60s. SSH/dashboard không cần.
wait_for_net() {
  _i=0
  while [ "$_i" -lt 30 ]; do
    if curl -m3 -sf -o /dev/null https://1.1.1.1 2>/dev/null; then log "net ready"; return 0; fi
    _i=$((_i + 1)); sleep 2
  done
  log "net chưa lên sau ~60s — vẫn tiếp tục"
}

# 1) Wake-lock
command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock && log "wake-lock acquired"

# 2) sshd (không cần internet)
if command -v sshd >/dev/null 2>&1; then
  if pgrep -x sshd >/dev/null 2>&1; then log "sshd already running"; else sshd && log "sshd started"; fi
fi

# 3) Dashboard (bind localhost, không cần internet) — start sớm
if [ -n "$HERMES" ] && [ -x "$HERMES" ]; then
  start_bg 'hermes dashboard' "$LOG_DIR/dashboard.log" \
    "$HERMES" dashboard --tui --host 0.0.0.0 --insecure --no-open
else
  log "hermes không tìm thấy ($HERMES) — bỏ qua dashboard/gateway"
fi

# 4) Chờ mạng rồi start gateway (Telegram) + cloudflared (cả hai cần internet)
wait_for_net

if [ -n "$HERMES" ] && [ -x "$HERMES" ]; then
  start_bg 'hermes gateway' "$LOG_DIR/gateway.log" "$HERMES" gateway
fi

# 5) cloudflared — token từ .env, truyền qua env TUNNEL_TOKEN (không lộ trong argv/ps)
if command -v cloudflared >/dev/null 2>&1; then
  CF_TOKEN="$(grep -E '^CLOUDFLARE_TUNNEL_TOKEN=' "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2- | tr -d "\"' ")"
  if [ -n "$CF_TOKEN" ]; then
    if pgrep -x cloudflared >/dev/null 2>&1; then
      log "cloudflared already running"
    else
      TUNNEL_TOKEN="$CF_TOKEN" nohup cloudflared tunnel run >> "$LOG_DIR/cloudflared.log" 2>&1 &
      log "cloudflared started pid=$!"
    fi
  else
    log "cloudflared: no CLOUDFLARE_TUNNEL_TOKEN in .env — skip"
  fi
fi

log "boot.sh done"
