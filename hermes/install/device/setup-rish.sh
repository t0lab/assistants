#!/data/data/com.termux/files/usr/bin/bash
# Đưa rish (Shizuku) vào $PREFIX/bin + set RISH_APPLICATION_ID, rồi test quyền shell.
# Tiền đề: đã cài + kích hoạt Shizuku (Wireless debugging) và đã lấy file `rish` + `rish_shizuku.dex`
# từ Shizuku app. Xem shizuku-rish.md.
#
# Dùng:  bash setup-rish.sh [thư-mục-chứa-rish]
set -u

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
BINDIR="$PREFIX/bin"

# 1) Tìm thư mục có cả `rish` và `*.dex`
search_dirs="${1:-} $HOME/storage/shared/rish $HOME/storage/downloads $HOME/downloads /sdcard/rish /sdcard/Download/rish $HOME"
src=""
for d in $search_dirs; do
  [ -n "$d" ] || continue
  if [ -f "$d/rish" ] && ls "$d"/*.dex >/dev/null 2>&1; then
    src="$d"; break
  fi
done

if [ -z "$src" ]; then
  echo "✗ Không tìm thấy 'rish' + '*.dex'."
  echo "  Lấy từ Shizuku app (menu 'Use Shizuku in terminal apps'), lưu vào /sdcard/rish/, rồi:"
  echo "    bash setup-rish.sh /sdcard/rish"
  exit 1
fi
echo "→ Nguồn rish: $src"

# 2) Copy rish + dex vào $PREFIX/bin (rish script load dex cùng thư mục, giữ nguyên tên)
cp "$src/rish" "$BINDIR/rish" && chmod +x "$BINDIR/rish" || { echo "✗ copy rish fail"; exit 1; }
for dex in "$src"/*.dex; do cp "$dex" "$BINDIR/"; done
echo "→ Đã copy rish + $(ls "$src"/*.dex | wc -l) file .dex vào $BINDIR"

# 3) RISH_APPLICATION_ID=com.termux vào ~/.bashrc (idempotent; shell tương tác)
profile="$HOME/.bashrc"
line='export RISH_APPLICATION_ID=com.termux'
if ! grep -qF "$line" "$profile" 2>/dev/null; then
  printf '\n# Shizuku rish\n%s\n' "$line" >> "$profile"
  echo "→ Thêm RISH_APPLICATION_ID vào $profile"
fi
export RISH_APPLICATION_ID=com.termux
echo "  (Lưu ý: MCP server đọc RISH_APPLICATION_ID từ config.yaml > mcp_servers.device.env,"
echo "   không phụ thuộc .bashrc — đã set sẵn ở đó.)"

# 3b) Capture env Android runtime cho tiến trình GATEWAY.
# Tiến trình do Termux:Boot (app com.termux.boot) spawn THIẾU BOOTCLASSPATH/ANDROID_*
# (app com.termux interactive thì có) → rish trả rỗng câm. Script này chạy từ interactive
# nên có sẵn → lưu lại để shell_backend nạp cho gateway. Chạy lại sau OS update.
mkdir -p "$HOME/.hermes"
env | grep -E '^(ANDROID|BOOTCLASSPATH|DEX2OATBOOTCLASSPATH)=' > "$HOME/.hermes/android-env"
echo "→ Capture android-env: $(wc -l < "$HOME/.hermes/android-env") biến → ~/.hermes/android-env"

# 4) Test
echo "→ Test: rish -c 'id'"
if out=$(rish -c 'id' 2>&1); then
  echo "  $out"
  case "$out" in
    *uid=2000*) echo "✓ rish OK (uid=shell). Backend 'rish' dùng được cho hermes/mcp." ;;
    *) echo "⚠ rish chạy nhưng chưa thấy uid=2000 — Shizuku đã Start + cấp quyền Termux chưa?" ;;
  esac
else
  echo "  $out"
  echo "✗ rish chưa chạy. Mở Shizuku → Start (Wireless debugging) → cấp quyền Termux, rồi chạy lại."
  exit 1
fi
