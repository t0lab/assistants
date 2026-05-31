"""Tool perception (read-only) cho điều khiển thiết bị qua backend shell.

Perception = XML (uiautomator dump) là chính + screenshot (screencap) bổ trợ.
File trung gian ghi ra /sdcard (shell UID ghi được, Termux đọc được) để tránh
hỏng dữ liệu nhị phân khi pipe qua rish/adb. Xem ADR device-control-via-adb.md.
"""
from __future__ import annotations

import base64
import os
import re
import shlex
import xml.etree.ElementTree as ET

from shell_backend import ShellError, run_shell

# Thư mục trung gian: shell UID ghi vào /sdcard, Termux đọc qua /storage/emulated/0.
SDCARD_REMOTE = os.environ.get("HERMES_DEVICE_SDCARD_REMOTE", "/sdcard")
_UI_REMOTE = f"{SDCARD_REMOTE}/hermes-ui.xml"
_SHOT_REMOTE = f"{SDCARD_REMOTE}/hermes-screen.png"

_BOUNDS_RE = re.compile(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]")
_FOCUS_RE = re.compile(r"\bu\d+\s+([\w.]+)/([\w.$]+)")


def _local_sdcard() -> str:
    """Đường Termux nhìn thấy /sdcard. Cần `termux-setup-storage` để có quyền đọc."""
    for cand in (
        os.environ.get("HERMES_DEVICE_SDCARD_LOCAL"),
        "/storage/emulated/0",
        os.path.expanduser("~/storage/shared"),
    ):
        if cand and os.path.isdir(cand):
            return cand
    return "/storage/emulated/0"


def _read_remote(remote: str, *, binary: bool = False) -> bytes | str:
    """Đọc file do shell ghi ra /sdcard. Ưu tiên đọc trực tiếp; fallback base64 qua shell."""
    local = os.path.join(_local_sdcard(), os.path.basename(remote))
    try:
        with open(local, "rb") as fh:
            data = fh.read()
    except OSError:
        # Termux chưa có quyền /sdcard → lấy qua shell bằng base64 (an toàn cho nhị phân)
        out, err, rc = run_shell(f"toybox base64 {shlex.quote(remote)}")
        if rc != 0:
            raise ShellError(
                f"Không đọc được {remote} (local lẫn base64 đều fail). "
                f"Chạy `termux-setup-storage`? stderr={err.strip()}"
            )
        data = base64.b64decode("".join(out.split()))
    return data if binary else data.decode("utf-8", "replace")


def _center(bounds: str) -> tuple[int, int] | None:
    m = _BOUNDS_RE.search(bounds or "")
    if not m:
        return None
    x1, y1, x2, y2 = (int(v) for v in m.groups())
    return (x1 + x2) // 2, (y1 + y2) // 2


def dump_ui(only_interesting: bool = True) -> dict:
    """Đọc cây UI hiện tại → danh sách element (text/desc/id/class + toạ độ tâm + clickable).

    only_interesting=True: chỉ giữ element có text/content-desc hoặc clickable (gọn cho LLM).
    """
    out, err, rc = run_shell(f"uiautomator dump {shlex.quote(_UI_REMOTE)}")
    if rc != 0 and "dumped" not in (out + err).lower():
        raise ShellError(
            f"uiautomator dump fail (rc={rc}): {err.strip() or out.strip()}. "
            "Màn hình secure/đang animation? Thử screenshot()."
        )
    xml = _read_remote(_UI_REMOTE, binary=False)
    try:
        root = ET.fromstring(xml)
    except ET.ParseError as exc:
        raise ShellError(f"Parse UI XML lỗi: {exc}. Thử screenshot().") from exc

    elements: list[dict] = []
    for node in root.iter("node"):
        a = node.attrib
        text = (a.get("text") or "").strip()
        desc = (a.get("content-desc") or "").strip()
        clickable = a.get("clickable") == "true"
        if only_interesting and not (text or desc or clickable):
            continue
        center = _center(a.get("bounds", ""))
        elements.append(
            {
                "text": text,
                "desc": desc,
                "id": a.get("resource-id", ""),
                "class": a.get("class", ""),
                "clickable": clickable,
                "center": center,  # [x, y] để tap, hoặc null nếu không có bounds
            }
        )
    return {"count": len(elements), "elements": elements}


def screenshot() -> bytes:
    """Chụp màn hình hiện tại → bytes PNG."""
    out, err, rc = run_shell(f"screencap -p {shlex.quote(_SHOT_REMOTE)}")
    if rc != 0:
        raise ShellError(f"screencap fail (rc={rc}): {err.strip() or out.strip()}")
    return _read_remote(_SHOT_REMOTE, binary=True)


def list_packages(third_party_only: bool = True) -> list[str]:
    """Liệt kê package đã cài (mặc định chỉ app bên thứ 3) — để biết tên gói khi open_app."""
    flag = " -3" if third_party_only else ""
    out, err, rc = run_shell(f"pm list packages{flag}")
    if rc != 0:
        raise ShellError(f"pm list packages fail (rc={rc}): {err.strip()}")
    pkgs = [
        line.split("package:", 1)[1].strip()
        for line in out.splitlines()
        if line.startswith("package:")
    ]
    return sorted(pkgs)


def current_app() -> dict:
    """App/Activity đang hiển thị (foreground). Trả {package, activity, raw}."""
    out, _err, _rc = run_shell(
        "dumpsys window 2>/dev/null | grep -E 'mCurrentFocus|mFocusedApp' | head -2"
    )
    pkg = activity = ""
    m = _FOCUS_RE.search(out)
    if m:
        pkg, activity = m.group(1), m.group(2)
    return {"package": pkg, "activity": activity, "raw": out.strip()}
