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
#                           Dùng cho Termux:Boot — reboot xong chưa có gì chạy nên start sạch.
#   sh boot.sh --restart  — kill gateway/dashboard/cloudflared rồi start lại (KHÔNG đụng sshd
#                           để không rớt phiên SSH). Dùng khi đổi config/code: git pull xong restart.

# PATH tối thiểu của Termux (môi trường boot có thể chưa set)
PATH=/data/data/com.termux/files/usr/bin:/data/data/com.termux/files/usr/bin/applets
export PATH

ENV_FILE="$HOME/.hermes/.env"
LOG_DIR="$HOME/.hermes/logs"
mkdir -p "$LOG_DIR"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_DIR/boot.log"; }
log "boot.sh start (${1:-boot})"

# --restart: kill các service do script quản (KHÔNG đụng sshd — tránh rớt phiên SSH hiện tại),
# rồi để phần dưới start lại sạch. Cổng dashboard 9119 chưa nhả kịp thì free luôn.
if [ "${1:-}" = "--restart" ] || [ "${1:-}" = "restart" ]; then
  log "restart: killing gateway/dashboard/cloudflared"
  pkill -f 'hermes gateway'   2>/dev/null
  pkill -f 'hermes dashboard' 2>/dev/null
  pkill -x cloudflared        2>/dev/null
  command -v fuser >/dev/null 2>&1 && fuser -k 9119/tcp 2>/dev/null   # nhả cổng dashboard
  sleep 2
fi

# start_bg <pgrep-pattern> <logfile> <cmd...> — chạy nền nếu chưa chạy (idempotent)
start_bg() {
  _pat="$1"; _log="$2"; shift 2
  if pgrep -f "$_pat" >/dev/null 2>&1; then
    log "[$_pat] already running"
  else
    nohup "$@" >> "$_log" 2>&1 &
    log "[$_pat] started pid=$!"
  fi
}

# 1) Wake-lock (cần Termux:API)
if command -v termux-wake-lock >/dev/null 2>&1; then
  termux-wake-lock && log "wake-lock acquired"
fi

# 2) sshd (port 8022)
if command -v sshd >/dev/null 2>&1; then
  if pgrep -x sshd >/dev/null 2>&1; then log "sshd already running"; else sshd && log "sshd started"; fi
fi

# 3) Hermes gateway (Telegram) — đọc TELEGRAM_* từ ~/.hermes/.env
if command -v hermes >/dev/null 2>&1; then
  start_bg 'hermes gateway' "$LOG_DIR/gateway.log" hermes gateway
fi

# 4) Hermes dashboard (web UI). --host 0.0.0.0 --insecure: BẮT BUỘC để WebSocket (chat/events/pty)
#    qua cloudflared vượt được Origin-guard. An toàn dựa vào Cloudflare Access ở public + NetBird riêng.
if command -v hermes >/dev/null 2>&1; then
  start_bg 'hermes dashboard' "$LOG_DIR/dashboard.log" \
    hermes dashboard --tui --host 0.0.0.0 --insecure --no-open
fi

# 5) cloudflared tunnel — token lấy từ .env (KHÔNG hardcode). Bỏ qua nếu thiếu token/cloudflared.
#    Truyền qua env TUNNEL_TOKEN để token không lộ trong `ps`/argv.
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
