#!/usr/bin/env python3
"""MCP server điều khiển thiết bị (no-root) cho Hermes Agent.

Pha 1: tool read-only (perception). Tool write (tap/swipe/input_text/open_app...)
+ allow-list/confirm sẽ thêm ở D4. Quyền shell qua backend rish (Shizuku) | adb.

Chạy: được Hermes spawn qua config.yaml > mcp_servers.device (stdio).
Tự test: HERMES_DEVICE_BACKEND=rish python3 server.py  (rồi dùng MCP client).
"""
from __future__ import annotations

import os
import sys

# Cho phép `import shell_backend` / `import device_tools` khi Hermes chạy `python3 server.py`.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from mcp.server.fastmcp import FastMCP, Image  # noqa: E402

import device_tools  # noqa: E402
import policy  # noqa: E402
import shell_backend  # noqa: E402

mcp = FastMCP("hermes-device")


def _log_write(action: str, detail: str = "") -> None:
    """Ghi audit hành động ghi vào ~/.hermes/logs/device.log (best-effort)."""
    try:
        import time

        logf = os.path.expanduser("~/.hermes/logs/device.log")
        os.makedirs(os.path.dirname(logf), exist_ok=True)
        ts = time.strftime("%Y-%m-%d %H:%M:%S")
        with open(logf, "a") as fh:
            fh.write(f"[{ts}] {action} {detail}\n")
    except Exception:
        pass


@mcp.tool()
def check_device() -> str:
    """Kiểm tra backend quyền shell (rish/adb) có hoạt động. Trả output `id` (mong uid=2000(shell))."""
    return shell_backend.check_backend()


@mcp.tool()
def dump_ui(only_interesting: bool = True) -> dict:
    """'Nhìn' màn hình: cây UI hiện tại → element (text/desc/id/class + toạ độ tâm + clickable).

    Đây là cách CHÍNH để đọc màn hình (rẻ, cho toạ độ chính xác để tap). Khi kết quả rỗng/
    không tin cậy (màn hình vẽ bằng canvas/game/secure), dùng screenshot().
    only_interesting=False để lấy toàn bộ node.
    """
    return device_tools.dump_ui(only_interesting=only_interesting)


@mcp.tool()
def screenshot() -> Image:
    """Chụp màn hình hiện tại → ảnh PNG. Dùng khi dump_ui không đủ, hoặc để gửi ảnh hỏi/báo user."""
    return Image(data=device_tools.screenshot(), format="png")


@mcp.tool()
def list_packages(third_party_only: bool = True) -> list[str]:
    """Liệt kê package đã cài (mặc định chỉ app bên thứ 3) — để lấy tên gói trước khi open_app."""
    return device_tools.list_packages(third_party_only=third_party_only)


@mcp.tool()
def find_package(keyword: str) -> list[str]:
    """Tìm tên package theo từ khoá trong MỌI app (kể cả cài sẵn). Dùng để lấy đúng package trước open_app (vd 'youtube' → com.google.android.youtube)."""
    return device_tools.find_package(keyword)


@mcp.tool()
def current_app() -> dict:
    """App/Activity đang hiển thị (foreground): {package, activity, raw}."""
    return device_tools.current_app()


# ---- Tool WRITE (action) — qua cổng policy ~/.hermes/device-policy.yaml ----
# Mặc định write_enabled=false → các tool dưới sẽ từ chối tới khi user bật.


@mcp.tool()
def tap(x: int, y: int) -> str:
    """Chạm vào toạ độ (x,y) (lấy từ `center` của dump_ui). Cần write_enabled trong device-policy.yaml."""
    policy.require_write("tap")
    _log_write("tap", f"{x},{y}")
    return device_tools.tap(x, y)


@mcp.tool()
def swipe(x1: int, y1: int, x2: int, y2: int, duration_ms: int = 300) -> str:
    """Vuốt từ (x1,y1) tới (x2,y2) trong duration_ms. Cần write_enabled."""
    policy.require_write("swipe")
    _log_write("swipe", f"{x1},{y1}->{x2},{y2}")
    return device_tools.swipe(x1, y1, x2, y2, duration_ms)


@mcp.tool()
def key(keycode: str) -> str:
    """Bấm phím: số (vd '4') hoặc tên (back/home/recent/enter/del/power...). Cần write_enabled."""
    policy.require_write("key")
    _log_write("key", str(keycode))
    return device_tools.key(keycode)


@mcp.tool()
def nav(target: str) -> str:
    """Điều hướng hệ thống: back | home | recent. Cần write_enabled."""
    policy.require_write("nav")
    _log_write("nav", target)
    return device_tools.nav(target)


@mcp.tool()
def input_text(text: str) -> str:
    """Gõ chữ (kể cả tiếng Việt) vào ô đang focus, qua ADBKeyBoard. Cần write_enabled + ADBKeyBoard là IME."""
    policy.require_write("input_text")
    _log_write("input_text", f"{len(text)} chars")
    return device_tools.input_text(text)


@mcp.tool()
def open_app(package: str) -> str:
    """Mở app theo package (vd com.google.android.youtube). Cần write_enabled + gói trong allowed_packages."""
    policy.require_write("open_app", package=package)
    _log_write("open_app", package)
    return device_tools.open_app(package)


@mcp.tool()
def open_url(url: str) -> str:
    """Mở URL/deeplink (https://, market://details?id=, https://wa.me/<num>?text=, geo:, https://youtube.com/results?search_query=). Cần write_enabled."""
    policy.require_write("open_url")
    _log_write("open_url", url)
    return device_tools.open_url(url)


@mcp.tool()
def kill_app(package: str) -> str:
    """Tắt (force-stop) app theo package. Cần write_enabled."""
    policy.require_write("kill_app")
    _log_write("kill_app", package)
    return device_tools.kill_app(package)


@mcp.tool()
def toggle(target: str, on: bool) -> str:
    """Bật/tắt wifi | bluetooth | airplane | data. Cần write_enabled."""
    policy.require_write("toggle")
    _log_write("toggle", f"{target}={on}")
    return device_tools.toggle(target, on)


@mcp.tool()
def brightness(value: int) -> str:
    """Đặt độ sáng màn hình 0–255. Cần write_enabled."""
    policy.require_write("brightness")
    _log_write("brightness", str(value))
    return device_tools.brightness(value)


@mcp.tool()
def volume(action: str) -> str:
    """Âm lượng: up | down | mute. Cần write_enabled."""
    policy.require_write("volume")
    _log_write("volume", action)
    return device_tools.volume(action)


@mcp.tool()
def lock_screen() -> str:
    """Khoá/tắt màn hình. Cần write_enabled."""
    policy.require_write("lock_screen")
    _log_write("lock_screen")
    return device_tools.lock_screen()


@mcp.tool()
def call(number: str) -> str:
    """Gọi điện thật tới số. Cần write_enabled + allow_telephony."""
    policy.require_write("call", telephony=True)
    _log_write("call", number)
    return device_tools.call(number)


@mcp.tool()
def sms_compose(number: str, body: str = "") -> str:
    """Mở trình soạn SMS đã điền sẵn (CHƯA gửi). Cần write_enabled + allow_telephony."""
    policy.require_write("sms_compose", telephony=True)
    _log_write("sms_compose", number)
    return device_tools.sms_compose(number, body)


@mcp.tool()
def device_info() -> dict:
    """Thông tin máy + pin: {model, android, battery_level, battery_status}. (đọc, không gate)"""
    return device_tools.device_info()


if __name__ == "__main__":
    mcp.run()
