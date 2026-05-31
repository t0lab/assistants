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
import shell_backend  # noqa: E402

mcp = FastMCP("hermes-device")


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
def current_app() -> dict:
    """App/Activity đang hiển thị (foreground): {package, activity, raw}."""
    return device_tools.current_app()


if __name__ == "__main__":
    mcp.run()
