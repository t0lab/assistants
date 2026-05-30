#!/usr/bin/env bash
# bootstrap.sh — cài Hermes Agent trên Termux (Android, chưa root). Idempotent.
# Tiền đề: đã làm xong install/SETUP-PHONE.md (Termux + build deps + adb phantom-killer).
#
# Việc của script:
#   1. link-home.sh TRƯỚC  → symlink SOUL/config.yaml/skills vào ~/.hermes/
#      (để upstream installer GIỮ NGUYÊN config của ta, không ghi default lên).
#   2. clone upstream hermes-agent (nếu chưa có).
#   3. ủy quyền cho upstream `scripts/install.sh` — nó lo phần khó của Termux:
#      shim psutil cho Python-android, build toolchain, venv, fallback extras
#      ([termux-all]→[termux]→core), symlink `hermes` vào PATH.
# Sau đó: điền ~/.hermes/.env rồi `hermes doctor`.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPSTREAM="https://github.com/NousResearch/hermes-agent.git"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
HERMES_REPO="$HERMES_HOME/hermes-agent"

usage() {
  cat <<EOF
Usage: bash bootstrap.sh [--help] [-- <args cho upstream install.sh>]

Cài Hermes Agent trên Termux (idempotent). Các bước:
  1. link-home.sh  — gắn config-as-code vào ~/.hermes/ (chạy trước)
  2. clone upstream NousResearch/hermes-agent → ~/.hermes/hermes-agent
  3. ủy quyền scripts/install.sh upstream (psutil shim, deps, venv, PATH)

Mọi tham số sau '--' được chuyển thẳng cho install.sh (vd: -- --dir /path).
Env: HERMES_HOME (mặc định ~/.hermes).
EOF
}

log()  { printf '\n\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }

# tách args: mọi thứ sau '--' forward cho install.sh
INSTALL_ARGS=()
case "${1:-}" in
  --help|-h) usage; exit 0 ;;
  --) shift; INSTALL_ARGS=("$@") ;;
  "") ;;
  *) warn "Tham số lạ: $1 (dùng '-- ...' để forward cho install.sh)"; usage; exit 2 ;;
esac

# --- Sanity: Termux? ---------------------------------------------------------
if [ -z "${PREFIX:-}" ] || [ ! -d "${PREFIX:-/nonexistent}/bin" ]; then
  warn "Không thấy \$PREFIX của Termux — script này dành cho Termux/Android. Vẫn tiếp tục."
fi

# --- RAM check (KHÔNG tự tạo swap: swapon cần root; HyperOS đã có zram) -------
if command -v free >/dev/null 2>&1; then
  total_mb="$(free -m | awk '/^Mem:/ {print $2}')"
  if [ -n "${total_mb:-}" ] && [ "$total_mb" -lt 7000 ]; then
    warn "RAM ~${total_mb}MB (<7GB). swapon cần root → không tạo swap được."
    warn "Nếu build bị kill: reboot + đóng app nền rồi chạy lại. (HyperOS có sẵn zram swap.)"
  fi
fi

# --- 1. Gắn config-as-code TRƯỚC --------------------------------------------
# install.sh chỉ tạo config.yaml/SOUL.md default khi VẮNG → link trước thì nó giữ của ta.
if [ -f "$SCRIPT_DIR/link-home.sh" ]; then
  log "Gắn config-as-code (link-home.sh) trước khi cài"
  bash "$SCRIPT_DIR/link-home.sh" || warn "link-home.sh báo lỗi — vẫn tiếp tục cài"
fi

# --- 2. clone upstream nếu chưa có ------------------------------------------
mkdir -p "$HERMES_HOME"
if [ -d "$HERMES_REPO/.git" ]; then
  log "Upstream đã có: $HERMES_REPO (install.sh sẽ tự cập nhật)"
else
  log "Clone upstream → $HERMES_REPO"
  git clone --recurse-submodules "$UPSTREAM" "$HERMES_REPO"
fi

# --- 3. ủy quyền upstream installer -----------------------------------------
log "Chạy upstream scripts/install.sh (psutil android shim + deps + venv + PATH)…"
cd "$HERMES_REPO"
bash scripts/install.sh "${INSTALL_ARGS[@]}"

# --- Done --------------------------------------------------------------------
log "Xong cài Hermes. Bước tiếp:"
cat <<EOF
  1. Điền secrets:   nano "$HERMES_HOME/.env"      # thêm OPENAI_API_KEY (LiteLLM)
  2. Kiểm tra:       hermes version && hermes doctor && hermes skills list
  3. Chạy:           hermes
EOF
