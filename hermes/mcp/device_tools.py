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
    """App/Activity đang hiển thị (foreground). Trả {package, activity, raw}.

    Lọc/parse trong Python — KHÔNG dùng grep/pipe/quote trong chuỗi lệnh (qua rish dễ vỡ).
    """
    pkg = activity = raw = ""
    # Nguồn 1: dumpsys window displays → mCurrentFocus (MIUI để field này ở 'displays')
    out, _e, _r = run_shell("dumpsys window displays")
    for line in out.splitlines():
        if "mCurrentFocus" in line:
            raw = line.strip()
            m = _FOCUS_RE.search(line)
            if m:
                pkg, activity = m.group(1), m.group(2)
            break
    # Nguồn 2 (fallback): dumpsys activity activities → ResumedActivity
    if not pkg:
        out2, _e, _r = run_shell("dumpsys activity activities")
        for line in out2.splitlines():
            if "ResumedActivity" in line:
                raw = raw or line.strip()
                m = _FOCUS_RE.search(line)
                if m:
                    pkg, activity = m.group(1), m.group(2)
                    break
    return {"package": pkg, "activity": activity, "raw": raw}


# ----------------------------------------------------------------------------
# Tool WRITE (action). Gọi qua cổng policy ở server.py (allow-list + write_enabled).
# Lệnh chỉ gồm số/định danh (không quote/pipe) để an toàn khi qua `rish -c`.
# ----------------------------------------------------------------------------

# Tên keyevent thông dụng → mã (cho key()/nav()).
KEYEVENTS = {
    "back": 4, "home": 3, "recent": 187, "enter": 66, "tab": 61,
    "del": 67, "power": 26, "volup": 24, "voldown": 25, "menu": 82, "search": 84,
}


def tap(x: int, y: int) -> str:
    out, err, rc = run_shell(f"input tap {int(x)} {int(y)}")
    if rc != 0:
        raise ShellError(f"tap fail: {err.strip() or out.strip()}")
    return f"tapped ({int(x)},{int(y)})"


def swipe(x1: int, y1: int, x2: int, y2: int, duration_ms: int = 300) -> str:
    out, err, rc = run_shell(
        f"input swipe {int(x1)} {int(y1)} {int(x2)} {int(y2)} {int(duration_ms)}"
    )
    if rc != 0:
        raise ShellError(f"swipe fail: {err.strip() or out.strip()}")
    return f"swiped ({x1},{y1})->({x2},{y2})"


def key(keycode) -> str:
    """keycode: số (vd 4) hoặc tên (back/home/recent/enter/del...)."""
    code = KEYEVENTS.get(str(keycode).strip().lower(), keycode)
    out, err, rc = run_shell(f"input keyevent {code}")
    if rc != 0:
        raise ShellError(f"keyevent {keycode} fail: {err.strip() or out.strip()}")
    return f"keyevent {keycode}"


def nav(target: str) -> str:
    """Điều hướng hệ thống: back | home | recent."""
    t = target.strip().lower()
    if t not in ("back", "home", "recent"):
        raise ShellError("nav chỉ nhận: back | home | recent")
    key(t)
    return f"nav {t}"


def input_text(text: str) -> str:
    """Gõ text (kể cả tiếng Việt/Unicode) qua ADBKeyBoard — broadcast base64, tránh quoting.

    Cần ADBKeyBoard đã cài + đang là IME (xem install/device/adbkeyboard.md). `input text`
    thường KHÔNG gõ được Unicode nên ta luôn dùng đường này.
    """
    b64 = base64.b64encode(text.encode("utf-8")).decode("ascii")
    out, err, rc = run_shell(f"am broadcast -a ADB_INPUT_B64 --es msg {b64}")
    if rc != 0:
        raise ShellError(f"input_text fail: {err.strip() or out.strip()}")
    # am luôn 'result=0' kể cả khi không receiver → không khẳng định được đã gõ.
    # Nếu chữ không hiện: ADBKeyBoard chưa cài / chưa set làm IME.
    return f"sent {len(text)} ký tự (qua ADBKeyBoard)"


def open_app(package: str) -> str:
    """Mở app theo package (monkey, không cần biết activity)."""
    out, err, rc = run_shell(
        f"monkey -p {package} -c android.intent.category.LAUNCHER 1"
    )
    blob = out + err
    if rc != 0 or "No activities found" in blob or "aborted" in blob:
        raise ShellError(f"open_app '{package}' fail: {blob.strip()}")
    return f"opened {package}"


def open_url(url: str) -> str:
    """Mở URL/deeplink qua VIEW intent (https://, market://, geo:, https://wa.me/..., tel: prefill...)."""
    out, err, rc = run_shell(
        f"am start -a android.intent.action.VIEW -d {shlex.quote(url)}"
    )
    if rc != 0 or "Error" in (out + err):
        raise ShellError(f"open_url fail: {(err or out).strip()}")
    return f"opened url: {url}"


def kill_app(package: str) -> str:
    """Tắt (force-stop) một app theo package."""
    out, err, rc = run_shell(f"am force-stop {shlex.quote(package)}")
    if rc != 0:
        raise ShellError(f"kill_app '{package}' fail: {(err or out).strip()}")
    return f"force-stopped {package}"


def toggle(target: str, on: bool) -> str:
    """Bật/tắt: wifi | bluetooth | airplane | data."""
    t = target.strip().lower()
    state = "enable" if on else "disable"
    if t == "wifi":
        cmd = f"svc wifi {state}"
    elif t == "bluetooth":
        cmd = f"svc bluetooth {state}"
    elif t == "data":
        cmd = f"svc data {state}"
    elif t == "airplane":
        cmd = f"cmd connectivity airplane-mode {state}"
    else:
        raise ShellError("toggle target: wifi | bluetooth | airplane | data")
    out, err, rc = run_shell(cmd)
    if rc != 0:
        raise ShellError(f"toggle {target} fail: {(err or out).strip()}")
    return f"{target} {'on' if on else 'off'}"


def brightness(value: int) -> str:
    """Đặt độ sáng màn hình 0–255."""
    v = max(0, min(255, int(value)))
    out, err, rc = run_shell(f"settings put system screen_brightness {v}")
    if rc != 0:
        raise ShellError(f"brightness fail: {(err or out).strip()}")
    return f"brightness {v}"


def volume(action: str) -> str:
    """Âm lượng: up | down | mute (qua keyevent)."""
    code = {"up": 24, "down": 25, "mute": 164}.get(action.strip().lower())
    if code is None:
        raise ShellError("volume: up | down | mute")
    return key(code)


def lock_screen() -> str:
    """Khoá/tắt màn hình (KEYCODE_SLEEP 223, fallback POWER 26)."""
    _o, _e, rc = run_shell("input keyevent 223")
    if rc != 0:
        run_shell("input keyevent 26")
    return "screen locked"


def call(number: str) -> str:
    """Gọi điện tới số (đặt cuộc gọi thật)."""
    out, err, rc = run_shell(
        f"am start -a android.intent.action.CALL -d {shlex.quote('tel:' + number)}"
    )
    if rc != 0 or "Error" in (out + err):
        raise ShellError(f"call fail: {(err or out).strip()}")
    return f"calling {number}"


def sms_compose(number: str, body: str = "") -> str:
    """Mở trình soạn SMS đã điền sẵn (CHƯA gửi — cần tap gửi, hoặc dùng termux-sms-send để gửi thật)."""
    cmd = f"am start -a android.intent.action.SENDTO -d {shlex.quote('sms:' + number)}"
    if body:
        cmd += f" --es sms_body {shlex.quote(body)}"
    out, err, rc = run_shell(cmd)
    if rc != 0 or "Error" in (out + err):
        raise ShellError(f"sms_compose fail: {(err or out).strip()}")
    return f"soạn SMS tới {number} (chưa gửi)"


def device_info() -> dict:
    """Thông tin máy + pin: {model, android, battery_level, battery_status}."""
    model, _e, _r = run_shell("getprop ro.product.model")
    ver, _e, _r = run_shell("getprop ro.build.version.release")
    batt, _e, _r = run_shell("dumpsys battery")
    level = status = ""
    for line in batt.splitlines():
        s = line.strip()
        if s.startswith("level:"):
            level = s.split(":", 1)[1].strip()
        elif s.startswith("status:"):
            status = s.split(":", 1)[1].strip()
    return {
        "model": model.strip(),
        "android": ver.strip(),
        "battery_level": level,
        "battery_status": status,
    }
