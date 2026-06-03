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
import time

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


# Marker chống CỤT output: subprocess capture stdout của rish đôi khi mất đuôi với output
# lớn (interactive `| wc -l` luôn đủ, nhưng python lúc đủ lúc thiếu). Bọc lệnh thành
# `<cmd>; printf '\n<MARK><rc>\n'` — marker mất = output bị cụt → retry; đồng thời khôi
# phục đúng exit code của <cmd> (vì rc của wrapper là rc của printf).
_MARK = "__RSH_e7a1c9__"


def run_shell(cmd: str, *, timeout: int | None = None) -> tuple[str, str, int]:
    """Chạy chuỗi shell `cmd` ở UID shell. Trả (stdout, stderr, returncode) dạng text.

    Có chống-cụt (marker + retry) → output luôn hoàn chỉnh hoặc raise. Dùng cho lệnh sinh
    text (uiautomator dump, pm list, dumpsys, input, monkey...). Lệnh ghi nhị phân
    (screencap) → ghi ra /sdcard rồi đọc bằng read_remote().
    """
    wrapped = f"{cmd}; printf '\\n{_MARK}%s\\n' \"$?\""
    argv = _build_argv(wrapped)
    err = ""
    for _ in range(3):
        try:
            # GỘP stderr→stdout: rish (Shizuku) đôi khi đẩy output của lệnh sang stderr thay
            # vì stdout (đã quan sát: cùng lệnh, lúc ra stdout lúc ra stderr). Gộp lại để parse
            # ổn định bất kể rish bỏ vào luồng nào.
            proc = subprocess.run(
                argv,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
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
        err = ""  # đã gộp vào out
        # rish thiếu RISH_APPLICATION_ID: in cảnh báo + exit 0 + KHÔNG chạy lệnh → bắt loud.
        if BACKEND == "rish" and "RISH_APPLICATION_ID is not set" in out:
            raise ShellError(
                "rish KHÔNG chạy lệnh: thiếu RISH_APPLICATION_ID trong tiến trình MCP. "
                "Pull code mới (shell_backend tự set) + restart gateway."
            )
        idx = out.rfind(_MARK)
        if idx != -1:                                    # output hoàn chỉnh (có marker)
            tail = out[idx + len(_MARK):].strip()
            try:
                rc = int(tail.split()[0]) if tail else proc.returncode
            except ValueError:
                rc = proc.returncode
            return out[:idx].rstrip("\n"), err, rc
        time.sleep(0.2)                                  # mất marker = cụt → thử lại
    raise ShellError(
        f"Output bị cụt sau 3 lần (rish/subprocess truncation): cmd={cmd[:80]!r}"
    )


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
