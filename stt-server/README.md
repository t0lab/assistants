# STT Server

whisper-live chạy trên home server với RTX 3060 12GB VRAM. Cung cấp high-accuracy Vietnamese STT qua WebSocket cho TimezAssistant app.

**Status:** Phase 4 — chưa implement. Độc lập, có thể làm song song với các phase khác.

## Specs

| Item | Value |
|------|-------|
| Model | `large-v3-turbo` |
| Language | `vi` (Vietnamese) |
| Backend | `faster_whisper` + CUDA |
| Vietnamese WER | ~7% |
| RTF trên RTX 3060 | ~0.1x (30s audio → ~3s xử lý) |
| VRAM usage | ~6GB (int8 quantized) |
| Port | 9090 WebSocket |

## Files (planned)

| File | Mô tả |
|------|-------|
| `docker-compose.yml` | whisper-live service với NVIDIA runtime |
| `config.yaml` | Model config: large-v3-turbo, vi, cuda, float16 |

## Quick start (sau khi implement)

```bash
# Trên home server
docker compose up -d

# Test
python3 test_ws.py  # gửi WAV tiếng Việt, nhận transcript
```

## Kết nối từ phone

App đọc URL từ Settings: `ws://<home-server-ip>:9090`

Khi phone ra ngoài mạng nhà: kết nối qua Tailscale IP của home server.

## Requirements

- Docker + NVIDIA Container Toolkit
- CUDA 12.4+
- RTX 3060 (hoặc GPU bất kỳ với ≥6GB VRAM)

## Xem thêm

- Exec plan Phase 4: `../docs/exec-plans/active/timezassistant-platform.md`
- Android app STT config: `../android-assistant/README.md`
