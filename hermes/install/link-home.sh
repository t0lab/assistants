#!/usr/bin/env bash
# link-home.sh — gắn config-as-code từ repo vào $HERMES_HOME và các profile.
#
#   home/         → $HERMES_HOME                  (default profile, ~/.hermes)
#   profiles/<n>/ → $HERMES_HOME/profiles/<n>/    (named profile, vd "friday";
#                                                 tự `hermes profile create` nếu chưa có)
#
# Với mỗi profile, link:
#   SOUL.md, config.yaml   → symlink file (config của ta thắng default install.sh)
#   skills/<skill>/        → symlink TỪNG skill (KHÔNG link cả thư mục skills/,
#                            vì install.sh sync skill bundled vào ~/.hermes/skills/;
#                            link cả dir sẽ đổ skill bundled vào repo).
#
# KHÔNG đụng .env / state.db / memories/ (runtime, không version-control) — kể cả
# với named profile (mỗi profile giữ .env + state riêng ở local).
# Idempotent: chạy lại an toàn. File default do install.sh tạo (config.yaml/SOUL.md)
# sẽ được lùi sang *.bak rồi thay bằng symlink — không mất gì.
set -euo pipefail

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"          # = hermes/

usage() {
  cat <<EOF
Usage: bash link-home.sh

Symlink config-as-code từ $REPO_ROOT vào $HERMES_HOME:
  - home/         → \$HERMES_HOME            (default profile)
  - profiles/<n>/ → \$HERMES_HOME/profiles/<n>/
Mỗi profile link SOUL.md, config.yaml (file) + skills/<skill>/ (từng skill).
Không chạm .env / *.db / memories/. Override đích bằng env HERMES_HOME.
EOF
}

case "${1:-}" in
  --help|-h) usage; exit 0 ;;
  "") ;;
  *) echo "Tham số lạ: $1" >&2; usage; exit 2 ;;
esac

# link_file <src_dir> <dst_dir> <name> — symlink src_dir/name → dst_dir/name
link_file() {
  local src_dir="$1" dst_dir="$2" item="$3"
  local src="$src_dir/$item" dst="$dst_dir/$item"
  if [ ! -e "$src" ]; then
    echo "  skip  $item — không có trong $src_dir"
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

# link_skills <src_dir> <dst_dir> — link từng skills/<skill>/ (giữ skill bundled cùng tồn tại)
link_skills() {
  local src_dir="$1" dst_dir="$2"
  [ -d "$src_dir/skills" ] || return 0
  mkdir -p "$dst_dir/skills"
  local linked=0 d name dst
  for d in "$src_dir"/skills/*/; do
    name="$(basename "$d")"
    dst="$dst_dir/skills/$name"
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
      echo "  ⚠ skills/$name là dir thật trong đích — bỏ qua (di chuyển nó nếu muốn link)"
      continue
    fi
    ln -sfn "${d%/}" "$dst"
    echo "  link  skills/$name → ${d%/}"
    linked=1
  done
  [ "$linked" -eq 0 ] && echo "  (chưa có skill nào trong $src_dir/skills/)"
}

# link_profile <src_dir> <dst_dir> [profile_name]
# profile_name set (named profile) → tự `hermes profile create` nếu CHƯA có (idempotent).
# Default profile (gọi không kèm name) bỏ qua — nó là ~/.hermes gốc của install.
link_profile() {
  local src_dir="$1" dst_dir="$2" pname="${3:-}"
  if [ -n "$pname" ] && [ ! -d "$dst_dir" ] && command -v hermes >/dev/null 2>&1; then
    echo "  profile create $pname (chưa có)"
    hermes profile create "$pname" </dev/null >/dev/null 2>&1 || true
  fi
  printf '\n→ %s\n   → %s\n' "$src_dir" "$dst_dir"
  mkdir -p "$dst_dir"
  link_file "$src_dir" "$dst_dir" SOUL.md
  link_file "$src_dir" "$dst_dir" config.yaml
  link_file "$src_dir" "$dst_dir" device-policy.yaml   # chỉ default profile có (friday: skip → không có device)
  link_skills "$src_dir" "$dst_dir"
}

printf '→ HERMES_HOME = %s\n→ REPO_ROOT   = %s\n' "$HERMES_HOME" "$REPO_ROOT"
shopt -s nullglob

# Đích đã link (để in trạng thái cuối)
LINKED_DIRS=("$HERMES_HOME")

# 1) Default profile: home/ → $HERMES_HOME
link_profile "$REPO_ROOT/home" "$HERMES_HOME"

# 2) Named profiles: profiles/<name>/ → $HERMES_HOME/profiles/<name>/ (tự tạo nếu chưa có)
for d in "$REPO_ROOT"/profiles/*/; do
  name="$(basename "$d")"
  dst="$HERMES_HOME/profiles/$name"
  link_profile "${d%/}" "$dst" "$name"
  LINKED_DIRS+=("$dst")
done

echo
echo "Trạng thái:"
for base in "${LINKED_DIRS[@]}"; do
  for p in SOUL.md config.yaml device-policy.yaml skills; do
    [ -e "$base/$p" ] && ls -ld "$base/$p" || true
  done
done
echo
echo "Xong. Sau khi cài Hermes: hermes skills list  (profile: hermes -p <name> skills list)"
