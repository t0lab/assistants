# MCP Root Server

Python MCP server cung cấp root-level tools cho OpenClaw Gateway. Chạy trong Termux với `USE_ROOT=true`.

**Status:** Phase 3 — chưa implement (cần Phase 2 Gateway xong trước).

## Tại sao cần server riêng

OpenClaw Gateway chạy user-level (không root) vì lý do bảo mật — prompt injection vào gateway root = toàn bộ device bị compromise. Thay vào đó, MCP server này nhận lệnh từ gateway và thực thi qua `su -c` với phạm vi kiểm soát rõ ràng.

## Files (planned)

| File | Mô tả |
|------|-------|
| `server.py` | MCP server entry point, đăng ký tools, khởi tạo ppadb connection |
| `root_tools.py` | `execute_root_command`, `read_file_root`, `list_processes` |
| `device_tools.py` | `get_battery_info`, `get_thermal_zones`, `get_memory_info` |
| `requirements.txt` | `mcp`, `pure-python-adb`, `PyYAML` |

## Tools (planned)

```python
# root_tools.py
execute_root_command(command: str) -> str   # su -c <command>
read_file_root(path: str) -> str            # đọc file yêu cầu root (/data/...)
list_processes() -> str                     # ps -A

# device_tools.py
get_battery_info() -> dict                  # capacity, temp_celsius, status, voltage
get_thermal_zones() -> dict                 # tất cả /sys/class/thermal/thermal_zone*/temp
get_memory_info() -> dict                   # /proc/meminfo
```

## Config trong openclaw-gateway/termux/mcp.json

```json
"android-root": {
  "command": "python3",
  "args": ["/data/data/com.termux/files/home/mcp-root/server.py"],
  "env": { "USE_ROOT": "true" }
}
```

## Test

```bash
# Sau khi deploy, từ Termux:
openclaw ask "pin điện thoại còn bao nhiêu phần trăm và máy đang nóng không"
# Kỳ vọng: trả lời chính xác dựa trên /sys/class/power_supply/battery/
```

## Xem thêm

- Exec plan Phase 3: `../docs/exec-plans/active/timezassistant-platform.md`
- Gateway config: `../openclaw-gateway/termux/README.md`
