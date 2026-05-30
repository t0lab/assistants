#!/data/data/com.termux/files/usr/bin/sh
# Termux:Boot startup — chạy MỖI lần thiết bị khởi động.
# Mục tiêu: phone "cắm điện là chạy" trên HyperOS chưa-root.
#   - termux-wake-lock : chặn CPU ngủ sâu giết tiến trình nền
#   - sshd             : bật lại SSH (port 8022) để truy cập từ laptop sau reboot
#   - (tùy chọn) hermes gateway : always-on khi đã cấu hình transport (Telegram…)
#
# CÀI: cần app Termux:Boot + Autostart đã bật (xem ../SETUP-PHONE.md Bước 2), rồi:
#   mkdir -p ~/.termux/boot
#   ln -sf ~/t0lab/assistants/hermes/install/persistence/boot.sh ~/.termux/boot/boot.sh
#   chmod +x ~/t0lab/assistants/hermes/install/persistence/boot.sh
# Chi tiết: persistence/README.md.

# PATH tối thiểu của Termux (môi trường boot có thể chưa set)
PATH=/data/data/com.termux/files/usr/bin:/data/data/com.termux/files/usr/bin/applets
export PATH

LOG="$HOME/.hermes/logs/boot.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }
log "boot.sh start"

# 1) Wake-lock (cần Termux:API). Không có thì bỏ qua.
if command -v termux-wake-lock >/dev/null 2>&1; then
  termux-wake-lock && log "wake-lock acquired"
fi

# 2) sshd (port 8022) — chỉ bật nếu chưa chạy
if command -v sshd >/dev/null 2>&1; then
  if pgrep -x sshd >/dev/null 2>&1; then
    log "sshd already running"
  else
    sshd && log "sshd started"
  fi
fi

# 3) (TÙY CHỌN) Hermes gateway always-on.
# Bỏ comment sau khi đã cấu hình transport (vd TELEGRAM_BOT_TOKEN trong ~/.hermes/.env).
# CLI tương tác (hermes TUI) KHÔNG hợp lý chạy ở boot — chỉ gateway mới chạy nền.
# if command -v hermes >/dev/null 2>&1; then
#   nohup hermes gateway start >> "$HOME/.hermes/logs/gateway.log" 2>&1 &
#   log "hermes gateway started (pid $!)"
# fi

log "boot.sh done"
