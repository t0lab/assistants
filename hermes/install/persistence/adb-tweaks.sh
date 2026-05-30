#!/usr/bin/env bash
# adb-tweaks.sh — tắt phantom-process killer của Android 12+/HyperOS qua adb (KHÔNG root).
# ⚠ CHẠY TRÊN PC (laptop có adb, phone cắm USB hoặc wireless-debug) — KHÔNG chạy trên phone.
# Giá trị có thể reset sau reboot/cập nhật → chạy lại khi Termux bị kill nền.
# Bản tự-động-hoá của ../SETUP-PHONE.md Bước 6c.
set -euo pipefail

if ! command -v adb >/dev/null 2>&1; then
  echo "✗ Không thấy adb. Cài Android Platform-Tools trên PC (xem ../SETUP-PHONE.md Bước 6a)." >&2
  exit 1
fi

state="$(adb get-state 2>/dev/null || true)"
if [ "$state" != "device" ]; then
  echo "✗ Chưa kết nối thiết bị (state='$state')." >&2
  echo "  Bật Developer options → USB debugging, cắm cáp data, rồi 'adb devices' phải thấy '<serial> device'." >&2
  echo "  (unauthorized = chưa bấm Allow trên phone; trống = sai cáp / charging-only)." >&2
  exit 1
fi

echo "→ Tắt phantom-process killer…"
adb shell "/system/bin/device_config set_sync_disabled_for_tests persistent"
adb shell "/system/bin/device_config put activity_manager max_phantom_processes 2147483647"

# Lệnh 3 cần 'USB debugging (Security settings)' (đòi Mi account + SIM trên HyperOS).
# Lỗi WRITE_SECURE_SETTINGS thì bỏ qua — lệnh 2 (max_phantom_processes) là biện pháp chính.
if adb shell settings put global settings_enable_monitor_phantom_procs false 2>/dev/null; then
  echo "  ✓ settings_enable_monitor_phantom_procs=false"
else
  echo "  ⚠ 'settings put global' bị từ chối (WRITE_SECURE_SETTINGS) — bỏ qua, không sao."
fi

echo "→ Verify:"
got="$(adb shell '/system/bin/device_config get activity_manager max_phantom_processes' 2>/dev/null | tr -d '\r')"
echo "  max_phantom_processes = ${got:-<unknown>}  (mong: 2147483647)"
echo "Xong."
