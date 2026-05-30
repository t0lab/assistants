#!/usr/bin/env bash
# link-home.sh — gắn config-as-code từ repo vào $HERMES_HOME (~/.hermes).
#
#   SOUL.md, config.yaml   → symlink file (config của ta thắng default install.sh)
#   skills/<skill>/        → symlink TỪNG skill (KHÔNG link cả thư mục skills/,
#                            vì install.sh sync skill bundled vào ~/.hermes/skills/;
#                            link cả dir sẽ đổ skill bundled vào repo).
#
# KHÔNG đụng .env / state.db / memories/ (runtime, không version-control).
# Idempotent: chạy lại an toàn. File default do install.sh tạo (config.yaml/SOUL.md)
# sẽ được lùi sang *.bak rồi thay bằng symlink — không mất gì.
set -euo pipefail

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_HOME="$(cd "$SCRIPT_DIR/../home" && pwd)"

usage() {
  cat <<EOF
Usage: bash link-home.sh

Symlink config-as-code từ $REPO_HOME vào $HERMES_HOME:
  - SOUL.md, config.yaml  (file)
  - skills/<skill>/        (từng skill một)
Không chạm .env / *.db / memories/. Override đích bằng env HERMES_HOME.
EOF
}

case "${1:-}" in
  --help|-h) usage; exit 0 ;;
  "") ;;
  *) echo "Tham số lạ: $1" >&2; usage; exit 2 ;;
esac

mkdir -p "$HERMES_HOME"
printf '→ HERMES_HOME = %s\n→ REPO_HOME   = %s\n\n' "$HERMES_HOME" "$REPO_HOME"

# link_file <name> — symlink REPO_HOME/<name> → HERMES_HOME/<name>
link_file() {
  local item="$1" src="$REPO_HOME/$1" dst="$HERMES_HOME/$1"
  if [ ! -e "$src" ]; then
    echo "  skip  $item — không có trong repo"
    return
  fi
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then            # file thật (vd default install.sh)
    if [ ! -e "$dst.bak" ]; then
      mv "$dst" "$dst.bak"
      echo "  backup $item → $item.bak (file cũ giữ lại)"
    else
      rm -f "$dst"                                       # đã có .bak từ lần trước
    fi
  fi
  ln -sfn "$src" "$dst"
  echo "  link  $item → $src"
}

link_file SOUL.md
link_file config.yaml

# skills: link từng subdir, để skill bundled của install.sh cùng tồn tại
mkdir -p "$HERMES_HOME/skills"
shopt -s nullglob
linked_skill=0
for d in "$REPO_HOME"/skills/*/; do
  name="$(basename "$d")"
  dst="$HERMES_HOME/skills/$name"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    echo "  ⚠ skills/$name là dir thật trong ~/.hermes — bỏ qua (di chuyển nó nếu muốn link)"
    continue
  fi
  ln -sfn "${d%/}" "$dst"
  echo "  link  skills/$name → ${d%/}"
  linked_skill=1
done
[ "$linked_skill" -eq 0 ] && echo "  (chưa có skill nào trong repo home/skills/ — T7)"

echo
echo "Trạng thái:"
for p in SOUL.md config.yaml skills; do
  [ -e "$HERMES_HOME/$p" ] && ls -ld "$HERMES_HOME/$p" || true
done
echo
echo "Xong. Sau khi cài Hermes: hermes skills list"
