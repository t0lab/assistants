"""Backend trừu tượng chạy lệnh ở UID shell (2000) — KHÔNG root.

Hai backend, chọn qua env HERMES_DEVICE_BACKEND:
  - "rish" : Shizuku (mặc định). `rish -c '<cmd>'` chạy `/system/bin/sh -c` ở UID shell.
  - "adb"  : self-ADB fallback. `adb shell '<cmd>'` (đã `adb connect localhost`).

Mọi tool điều khiển thiết bị đi qua run_shell() — đổi cơ chế quyền chỉ là đổi env,
không sửa code tool. Xem ADR docs/design-docs/device-control-via-adb.md.
"""
from __future__ import annotations

import os
import subprocess

BACKEND = os.environ.get("HERMES_DEVICE_BACKEND", "rish").strip().lower()
DEFAULT_TIMEOUT = int(os.environ.get("HERMES_DEVICE_TIMEOUT", "30"))

# rish CẦN env RISH_APPLICATION_ID (= app gọi nó, Termux). Gateway có thể không truyền
# env của mcp_servers.device qua subprocess (hoặc config bị Hermes rewrite mất) → tự đặt
# mặc định để không phụ thuộc config-env. Nếu thiếu, rish in "RISH_APPLICATION_ID is not
# set" ra stdout + exit 0 (rc=0, không có uid=) → tưởng nhầm backend hỏng.
if BACKEND == "rish":
    os.environ.setdefault("RISH_APPLICATION_ID", "com.termux")


class ShellError(RuntimeError):
    """Lỗi khi chạy lệnh qua backend (backend chưa kích hoạt, timeout, lệnh fail)."""


def _build_argv(cmd: str) -> list[str]:
    if BACKEND == "rish":
        # rish -c '<cmd>'  → /system/bin/sh -c '<cmd>' ở UID shell (qua Shizuku)
        return ["rish", "-c", cmd]
    if BACKEND == "adb":
        # adb shell nhận cả chuỗi lệnh làm 1 đối số
        return ["adb", "shell", cmd]
    raise ShellError(
        f"HERMES_DEVICE_BACKEND không hợp lệ: {BACKEND!r} (chỉ 'rish' hoặc 'adb')"
    )


def run_shell(cmd: str, *, timeout: int | None = None) -> tuple[str, str, int]:
    """Chạy chuỗi shell `cmd` ở UID shell. Trả (stdout, stderr, returncode) dạng text.

    Dùng cho lệnh sinh text (uiautomator dump, pm list, dumpsys, input...).
    Lệnh ghi file nhị phân (screencap) → ghi ra /sdcard rồi đọc bằng read_remote().
    """
    argv = _build_argv(cmd)
    try:
        proc = subprocess.run(
            argv,
            capture_output=True,
            timeout=timeout or DEFAULT_TIMEOUT,
        )
    except FileNotFoundError as exc:
        raise ShellError(
            f"Không tìm thấy backend '{BACKEND}' ({argv[0]}). "
            f"Đã cài/kích hoạt chưa? (Shizuku→rish hoặc adb connect). Chi tiết: {exc}"
        ) from exc
    except subprocess.TimeoutExpired as exc:
        raise ShellError(f"Lệnh quá {timeout or DEFAULT_TIMEOUT}s: {cmd}") from exc
    out = proc.stdout.decode("utf-8", "replace")
    err = proc.stderr.decode("utf-8", "replace")
    return out, err, proc.returncode


def check_backend() -> str:
    """Xác nhận backend chạy được lệnh shell. Trả output của `id` (mong uid=2000(shell))."""
    out, err, rc = run_shell("id")
    if rc != 0 or "uid=" not in out:
        raise ShellError(
            f"Backend '{BACKEND}' không chạy được lệnh shell (rc={rc}). "
            f"stdout={out.strip()[:200]!r} stderr={err.strip()[:200]!r}. "
            "Nếu thấy 'RISH_APPLICATION_ID is not set' → env chưa tới rish; "
            "nếu rỗng → Shizuku chưa Start (kích hoạt lại sau reboot)."
        )
    return out.strip()
