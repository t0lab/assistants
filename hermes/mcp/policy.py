"""Cổng allow-list cho tool WRITE. Đọc ~/.hermes/device-policy.yaml (user tự sửa).

Mặc định CHẶN mọi hành động ghi (an toàn): agent reachable qua Telegram/web → prompt
injection có thể xui agent thao tác máy. User bật/giới hạn ở device-policy.yaml.
Xem ADR device-control-via-adb.md (Decision #5).
"""
from __future__ import annotations

import os

POLICY_PATH = os.environ.get(
    "HERMES_DEVICE_POLICY", os.path.expanduser("~/.hermes/device-policy.yaml")
)

_DEFAULTS = {
    "write_enabled": False,     # tắt mọi tool ghi (chỉ đọc) — mặc định an toàn
    "allow_all_packages": False,  # open_app mọi gói (bỏ qua allowed_packages)
    "allowed_packages": [],     # open_app chỉ các gói này
    "allow_telephony": False,   # call/sms (tốn tiền/gửi thật) — chặn riêng dù write_enabled=true
}


class PolicyError(RuntimeError):
    """Hành động ghi bị device-policy.yaml chặn."""


def _load() -> dict:
    data: object = {}
    try:
        import yaml

        with open(POLICY_PATH) as fh:
            data = yaml.safe_load(fh) or {}
    except FileNotFoundError:
        data = {}            # không có file → mặc định deny
    except Exception:
        data = {}            # parse lỗi → deny (an toàn hơn cho phép nhầm)
    merged = dict(_DEFAULTS)
    if isinstance(data, dict):
        merged.update(data)
    return merged


def require_write(
    action: str, package: str | None = None, telephony: bool = False
) -> None:
    """Raise PolicyError nếu hành động ghi không được phép."""
    p = _load()
    if not p.get("write_enabled"):
        raise PolicyError(
            f"Hành động ghi '{action}' bị CHẶN — write_enabled=false (mặc định) ở {POLICY_PATH}. "
            "Sửa file, đặt write_enabled: true để cho phép điều khiển."
        )
    if telephony and not p.get("allow_telephony"):
        raise PolicyError(
            f"'{action}' (gọi/SMS) bị CHẶN — allow_telephony=false ở {POLICY_PATH}. "
            "Đặt allow_telephony: true nếu thật sự muốn agent gọi điện/nhắn tin."
        )
    if package is not None and not p.get("allow_all_packages"):
        allowed = p.get("allowed_packages") or []
        if package not in allowed:
            raise PolicyError(
                f"open_app '{package}' không nằm trong allowed_packages ({POLICY_PATH}). "
                "Thêm gói vào danh sách, hoặc đặt allow_all_packages: true."
            )
