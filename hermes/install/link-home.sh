#!/usr/bin/env bash
# link-home.sh — symlink config-as-code assets từ repo vào $HERMES_HOME (~/.hermes).
# Chỉ link SOUL.md, config.yaml, skills/. KHÔNG đụng .env / state.db / memories/ (runtime, không version-control).
# Idempotent: chạy lại an toàn — thay symlink cũ, nhưng TỪ CHỐI ghi đè file/dir thật (tránh mất dữ liệu).
set -euo pipefail

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_HOME="$(cd "$SCRIPT_DIR/../home" && pwd)"

ASSETS=(SOUL.md config.yaml skills)

usage() {
  cat <<EOF
Usage: bash link-home.sh

Symlink các asset config-as-code từ:
  $REPO_HOME/{$(IFS=,; echo "${ASSETS[*]}")}
vào:
  $HERMES_HOME/

Override đích bằng env HERMES_HOME. Không chạm .env / *.db / memories/.
EOF
}

[ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ] && { usage; exit 0; }

mkdir -p "$HERMES_HOME"
echo "→ HERMES_HOME = $HERMES_HOME"
echo "→ REPO_HOME   = $REPO_HOME"
echo

for item in "${ASSETS[@]}"; do
  src="$REPO_HOME/$item"
  dst="$HERMES_HOME/$item"

  if [ ! -e "$src" ]; then
    echo "  skip  $item — không có trong repo ($src)"
    continue
  fi

  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    echo "  ⚠ TỪ CHỐI $item — '$dst' là file/dir thật, không phải symlink."
    echo "             Sao lưu/di chuyển nó rồi chạy lại nếu muốn link."
    continue
  fi

  ln -sfn "$src" "$dst"        # -n: không chui vào dir đã là symlink
  echo "  link  $item → $src"
done

echo
echo "Trạng thái:"
for item in "${ASSETS[@]}"; do
  [ -e "$HERMES_HOME/$item" ] && ls -ld "$HERMES_HOME/$item" || true
done
echo
echo "Xong. Kiểm tra: hermes skills list   (sau khi đã cài Hermes)"
