# Device Safety

Scripts bảo vệ thiết bị chạy với root qua Magisk module. Mục tiêu: phone chạy 24/7 làm gateway mà không hỏng pin hoặc quá nhiệt.

**Status:** Phase 1 — chưa implement.

## Scripts (planned)

| Script | Trigger | Action |
|--------|---------|--------|
| `scripts/battery-guard.sh` | temp > 45°C | Termux notification |
| `scripts/battery-guard.sh` | capacity ≥ 80% + đang sạc | Log warning |
| `scripts/thermal-monitor.sh` | any thermal zone > 60°C | Release wakelock, log |
| `scripts/wakelock-manager.sh` | Gateway start/stop | acquire/release partial wakelock |
| `scripts/health-report.sh` | on-demand | In ra battery + temp + RAM stats |

## Magisk Module

```
magisk-module/
├── module.prop           id=timezlab-device-guard, version=1.0
├── service.sh            chạy post-boot với root
└── META-INF/com/google/android/
    ├── update-binary     standard Magisk installer binary
    └── updater-script    assert true
```

`service.sh` sleep 30s (đợi Termux mount) rồi khởi động battery-guard và thermal-monitor ở background.

## Deploy

```bash
# Từ dev machine qua ADB
bash deploy.sh
```

`deploy.sh` push scripts lên `/data/local/tmp/device-guard/` và copy Magisk module vào `/sdcard/Download/` để cài thủ công.

## Xem thêm

- Exec plan Phase 1: `../docs/exec-plans/active/timezassistant-platform.md`
