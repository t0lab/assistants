#!/usr/bin/env bash
# bootstrap.sh — cài Hermes Agent trên Termux (Android, chưa root). Idempotent.
# Tiền đề: đã làm xong install/SETUP-PHONE.md (Termux + build deps + adb phantom-killer).
# Việc của script: cài pkg deps → clone upstream → venv + pip install (.[termux]) → symlink `hermes`.
# Sau đó chạy install/link-home.sh để gắn SOUL/config/skills, rồi `hermes doctor`.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPSTREAM="https://github.com/NousResearch/hermes-agent.git"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
HERMES_REPO="$HERMES_HOME/hermes-agent"
PKGS=(git python clang rust make pkg-config libffi openssl nodejs ripgrep ffmpeg)

usage() {
  cat <<EOF
Usage: bash bootstrap.sh [--skip-deps] [--help]

Cài Hermes Agent trên Termux. Idempotent — chạy lại an toàn.
  --skip-deps   Bỏ qua bước 'pkg install' (đã cài tay rồi)
  --help, -h    In hướng dẫn này

Env: HERMES_HOME (mặc định ~/.hermes) — nơi đặt clone + config + state.
EOF
}

log()  { printf '\n\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }

SKIP_DEPS=0
case "${1:-}" in
  --help|-h) usage; exit 0 ;;
  --skip-deps) SKIP_DEPS=1 ;;
  "") ;;
  *) warn "Tham số lạ: $1"; usage; exit 2 ;;
esac

# --- Sanity: Termux? ---------------------------------------------------------
if [ -z "${PREFIX:-}" ] || [ ! -d "${PREFIX:-/nonexistent}/bin" ]; then
  warn "Không thấy \$PREFIX của Termux — script này thiết kế cho Termux/Android."
  warn "Vẫn tiếp tục, nhưng bước symlink \`hermes\` vào \$PREFIX/bin sẽ bị bỏ qua."
fi

# --- RAM check (KHÔNG tự tạo swap: swapon cần root; HyperOS đã có sẵn zram) ----
if command -v free >/dev/null 2>&1; then
  total_mb="$(free -m | awk '/^Mem:/ {print $2}')"
  if [ -n "${total_mb:-}" ] && [ "$total_mb" -lt 7000 ]; then
    warn "RAM ~${total_mb}MB (<7GB). swapon cần root → không tạo swap được."
    warn "Nếu build bị kill: reboot + đóng app nền rồi chạy lại. (HyperOS có sẵn zram swap.)"
  fi
fi

# --- 1. pkg deps -------------------------------------------------------------
if [ "$SKIP_DEPS" -eq 0 ] && command -v pkg >/dev/null 2>&1; then
  log "Cài build deps: ${PKGS[*]}"
  pkg install -y "${PKGS[@]}"
else
  log "Bỏ qua pkg deps (--skip-deps hoặc không có 'pkg')."
fi

# --- 2. clone / update upstream ---------------------------------------------
mkdir -p "$HERMES_HOME"
if [ -d "$HERMES_REPO/.git" ]; then
  log "Cập nhật upstream: $HERMES_REPO"
  git -C "$HERMES_REPO" pull --recurse-submodules --ff-only || warn "git pull bỏ qua (có local changes?)"
else
  log "Clone upstream → $HERMES_REPO"
  git clone --recurse-submodules "$UPSTREAM" "$HERMES_REPO"
fi
cd "$HERMES_REPO"

# --- 3. venv + pip install (.[termux]) --------------------------------------
if [ ! -d venv ]; then
  log "Tạo venv"
  python -m venv venv
fi
# shellcheck disable=SC1091
source venv/bin/activate

if command -v getprop >/dev/null 2>&1; then
  export ANDROID_API_LEVEL="$(getprop ro.build.version.sdk)"
  log "ANDROID_API_LEVEL=$ANDROID_API_LEVEL"
fi

log "pip install -e .[termux] (prebuilt wheels qua constraints-termux.txt)"
pip install -U pip setuptools wheel
pip install -e '.[termux]' -c constraints-termux.txt

# --- 4. symlink `hermes` vào PATH -------------------------------------------
if [ -n "${PREFIX:-}" ] && [ -x "$PWD/venv/bin/hermes" ]; then
  ln -sf "$PWD/venv/bin/hermes" "$PREFIX/bin/hermes"
  log "Symlink: $PREFIX/bin/hermes → venv/bin/hermes"
fi

# --- Done --------------------------------------------------------------------
log "Xong cài Hermes. Bước tiếp:"
cat <<EOF
  1. Gắn config-as-code:   bash "$SCRIPT_DIR/link-home.sh"
  2. Điền secrets:         cp <repo>/hermes/.env.example "$HERMES_HOME/.env" && nano "$HERMES_HOME/.env"
  3. Kiểm tra:             hermes version && hermes doctor
EOF
