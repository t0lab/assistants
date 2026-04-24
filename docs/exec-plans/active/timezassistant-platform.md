# Exec Plan: TimezAssistant Platform

**Status:** active
**Created:** 2026-04-24
**Owner:** liamlee

## Goal

Phone (Redmi Note 11S, LineageOS+Root) chạy OpenClaw Gateway standalone, có wake word + persistent voice conversation qua Android app, bảo vệ thiết bị tự động, và STT on-premise trên home server RTX 3060.

## Background

Trước đó Gateway chạy Docker trên Linux host — phone chỉ là companion node. Mục tiêu mới là phone tự chủ hoàn toàn (no external server required at runtime). Cần rebuild toàn bộ deployment stack và xây Android app mới vì app chính thức của OpenClaw không có wake word + persistent session.

Các quyết định kiến trúc: `docs/design-docs/gateway-on-termux.md`, `docs/design-docs/root-via-mcp.md`, `docs/design-docs/stt-pluggable-provider.md`, `docs/design-docs/voice-session-persistent.md`.

## Blockers

None hiện tại.

## Out of scope

- iOS / macOS app
- Multi-user support
- OpenClaw Gateway hosted trên cloud (Fly.io, Hetzner, v.v.)
- Local LLM inference trên phone (Termux resources không đủ)
- Push notifications từ Gateway ra ngoài internet (chỉ cần local + Tailscale)

## Decisions log

- 2026-04-24: Gateway Termux native (không Docker). Xem `docs/design-docs/gateway-on-termux.md`.
- 2026-04-24: Root access qua MCP `su -c`, Gateway không root. Xem `docs/design-docs/root-via-mcp.md`.
- 2026-04-24: STT pluggable interface — SherpaOnnx default, WhisperLive option. Xem `docs/design-docs/stt-pluggable-provider.md`.
- 2026-04-24: Voice session persistent (multi-turn). Xem `docs/design-docs/voice-session-persistent.md`.
- 2026-04-24: Wake word engine: Porcupine (offline, free 1 custom wake word, ~0.5% CPU).
- 2026-04-24: whisper-live model: large-v3-turbo (RTX 3060 12GB, RTF ~0.1x, Vietnamese WER ~7%).

---

## Architecture tổng thể

```
┌─────────────────────────────────────────────────────┐
│  Home Server (RTX 3060)                             │
│  └── stt-server/  whisper-live (Docker+CUDA)        │
│      WebSocket ws://homeserver:9090                 │
└────────────────────┬────────────────────────────────┘
                     │ Tailscale
┌────────────────────▼────────────────────────────────┐
│  Phone: LineageOS + Magisk (root)                   │
│                                                     │
│  Termux:                                            │
│  ├── OpenClaw Gateway  (Node.js, port 4000)         │
│  └── mcp-root/server.py  (Python MCP, root tools)  │
│                                                     │
│  Apps:                                              │
│  ├── TimezAssistant  ← NEW                          │
│  │   ├── WakeWordService  (Porcupine, background)   │
│  │   ├── VoiceSessionService  (foreground)          │
│  │   │   ├── STT: SherpaOnnx (default, on-device)  │
│  │   │   │    OR  WhisperLive (home server)         │
│  │   │   ├── OpenClaw module  (ws://localhost:4000) │
│  │   │   └── TTS: Android built-in                 │
│  │   └── Settings: STT provider, Gateway URL        │
│  └── OpenClaw companion node app  (official APK)   │
│                                                     │
│  Magisk modules:                                    │
│  ├── device-guard  (battery/thermal scripts)        │
│  └── gateway-autostart  (boot → start Termux+GW)   │
└─────────────────────────────────────────────────────┘
```

---

## Cấu trúc thư mục (current — P0 complete)

```
assistants/
├── openclaw-gateway/
│   ├── termux/             # ← P2: bootstrap.sh, start.sh, mcp.json
│   ├── workspace/          # Shared agent workspace (AGENTS.md, SOUL, MEMORY)
│   ├── state/              # Runtime state (OpenClaw managed)
│   └── skills/             # OpenClaw skills
├── device/
│   ├── scripts/            # ← P1: battery-guard.sh, thermal-monitor.sh, wakelock-manager.sh
│   ├── magisk-module/      # ← P1: module.prop, service.sh
│   └── deploy.sh           # ← P1
├── mcp-root/               # ← P3: server.py, root_tools.py, device_tools.py
├── stt-server/             # ← P4: docker-compose.yml, config.yaml
├── android-assistant/      # ← P5: Kotlin app com.timezlab.assistant
│   └── app/src/main/java/com/timezlab/assistant/
│       ├── service/        # WakeWordService, VoiceSessionService
│       ├── stt/            # STTProvider, SherpaOnnxSTT, WhisperLiveSTT
│       ├── vad/            # SileroVAD
│       ├── tts/            # TTSManager
│       ├── modules/openclaw/ # OpenClawModule, OpenClawWebSocketClient
│       └── ui/             # MainActivity, SettingsActivity, VoiceOverlayView
└── bak/
    └── openclaw-gateway-docker/  # Old Docker deployment (archived)
```

---

## Phase 0 — Repo Restructure

**Mục tiêu:** Dọn thư mục, tạo skeleton đúng cấu trúc đích trước khi code.

| Task | Việc cần làm | Done when |
|------|-------------|-----------|
| T0.1 | Tạo `openclaw-gateway/docker/` ← move nội dung `openclaw/` vào | `openclaw/` không còn tồn tại, docker-compose.yml tại `openclaw-gateway/docker/` chạy được |
| T0.2 | Tạo `openclaw-gateway/termux/` skeleton (bootstrap.sh, start.sh, mcp.json, env.example) | Files tồn tại, `bootstrap.sh --help` in ra usage |
| T0.3 | Tạo skeleton `device/`, `mcp-root/`, `stt-server/`, `android-assistant/` | Mỗi dir có README.md mô tả mục đích |
| T0.4 | Update `AGENTS.md` — thêm map các dir mới | AGENTS.md phản ánh đúng cấu trúc |
| T0.5 | Move `openclaw-2026.4.22-thirdParty-debug.apk` vào `android-assistant/prebuilt/` | APK tại đúng chỗ |

**Thời gian ước tính:** 1–2 giờ

---

## Phase 1 — Device Safety (Magisk Module)

**Mục tiêu:** Các script bảo vệ thiết bị chạy persistent với root qua Magisk, tự khởi động sau boot.

### T1.1 — battery-guard.sh

```
Input:  /sys/class/power_supply/battery/{capacity,temp,status}
Logic:
  - Nếu temp > 45°C → gửi Termux notification "NHIỆT CAO: {temp}°C"
  - Nếu capacity >= 80% AND status = Charging → log cảnh báo sạc quá mức
  - Loop mỗi 60s
Output: /data/local/tmp/battery-guard.log
```

Done: Script chạy background, notification xuất hiện khi test `temp=460` (46°C).

### T1.2 — thermal-monitor.sh

```
Input:  /sys/class/thermal/thermal_zone*/temp  (đọc tất cả zones)
Logic:
  - Zone nào > 50°C → log + notification
  - Zone nào > 60°C → trigger wakelock release để giảm tải
Loop: mỗi 30s
```

Done: Chạy 5 phút không crash, log có timestamp.

### T1.3 — wakelock-manager.sh

```
acquire():  echo "timezassistant_lock" > /sys/power/wake_lock
release():  echo "timezassistant_lock" > /sys/power/wake_unlock
status():   cat /sys/power/wake_lock | grep timezassistant
```

Done: `acquire && status` trả về lock name, `release && status` không còn tên.

### T1.4 — Magisk Module packaging

```
magisk-module/
├── module.prop           id=device-guard, version=1.0
├── service.sh            ← chạy sau boot với root
│   #!/system/bin/sh
│   sleep 30             # đợi Termux mount
│   sh /data/local/tmp/device-guard/battery-guard.sh &
│   sh /data/local/tmp/device-guard/thermal-monitor.sh &
└── META-INF/com/google/android/
    ├── update-binary     (standard Magisk installer)
    └── updater-script    (assert true)
```

Done: Cài module qua Magisk Manager, reboot, cả 2 script chạy (`ps | grep guard` thấy PIDs).

### T1.5 — deploy.sh

```bash
# Dùng từ dev machine
adb push scripts/ /data/local/tmp/device-guard/
adb shell chmod +x /data/local/tmp/device-guard/*.sh
adb push magisk-module/ /sdcard/Download/device-guard-module/
```

Done: `deploy.sh` chạy không lỗi, file tồn tại trên phone.

**Thời gian ước tính:** 3–4 giờ

---

## Phase 2 — OpenClaw Gateway on Termux

**Mục tiêu:** Gateway chạy native trong Termux, tự khởi động sau boot, accessible qua localhost và Tailscale.

### T2.1 — termux/bootstrap.sh

```bash
#!/data/data/com.termux/files/usr/bin/bash
# Idempotent — chạy lại cũng không lỗi
pkg update -y
pkg install -y nodejs-lts python3 git curl

# Install openclaw
npm install -g openclaw

# Setup env
cp env.example ~/.openclaw-env
echo "source ~/.openclaw-env" >> ~/.bashrc

# Install Python deps cho mcp-root
pip install mcp pure-python-adb PyYAML
```

Done: `openclaw --version` in ra version trong Termux shell.

### T2.2 — termux/mcp.json

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem",
               "/data/data/com.termux/files/home/.openclaw/workspace"]
    },
    "sqlite": {
      "command": "python3",
      "args": ["-m", "mcp_server_sqlite",
               "--db-path", "/data/data/com.termux/files/home/.openclaw/workspace/db.sqlite"]
    },
    "android-root": {
      "command": "python3",
      "args": ["/data/data/com.termux/files/home/mcp-root/server.py"],
      "env": { "USE_ROOT": "true" }
    }
  }
}
```

Done: `openclaw mcp list` trong Termux liệt kê đủ 3 servers.

### T2.3 — termux/start.sh

```bash
#!/data/data/com.termux/files/usr/bin/bash
source ~/.openclaw-env
# Acquire wakelock
sh /data/local/tmp/device-guard/wakelock-manager.sh acquire
# Start gateway
openclaw gateway start --port 4000 --daemon
echo "[gateway] Started at $(date)"
```

Done: `curl localhost:4000/health` → 200 OK từ Termux.

### T2.4 — Magisk boot trigger

```bash
# Thêm vào magisk-module/service.sh
sleep 60
am start -n com.termux/com.termux.app.TermuxActivity
input text "~/mcp-root/../openclaw-gateway/termux/start.sh"$'\n'
```

Done: Sau reboot, Gateway tự chạy, `curl localhost:4000/health` OK trong vòng 90s.

### T2.5 — Tailscale access

Done: Từ laptop, `curl http://<phone-tailscale-ip>:4000/health` → 200 OK.

**Thời gian ước tính:** 4–5 giờ

---

## Phase 3 — Root MCP Server

**Mục tiêu:** OpenClaw có thể chạy root-level commands trên phone thông qua MCP tools.

### T3.1 — server.py (base)

```python
# Extends android-mcp-server pattern
# MCP server với ppadb → localhost:5037 (Termux adb server)
# Hoặc subprocess.run(["su", "-c", cmd]) khi USE_ROOT=true
```

### T3.2 — root_tools.py

```python
@mcp.tool()
def execute_root_command(command: str) -> str:
    """Execute a shell command with root privileges via `su -c`."""
    result = subprocess.run(
        ["su", "-c", command],
        capture_output=True, text=True, timeout=30
    )
    return result.stdout or result.stderr

@mcp.tool()
def read_file_root(path: str) -> str:
    """Read a file that requires root access (e.g. /data/...)."""

@mcp.tool()
def list_processes() -> str:
    """List all running processes with root (ps -A)."""
```

Done: `openclaw ask "đọc /proc/version"` → kernel string trả về qua MCP.

### T3.3 — device_tools.py

```python
@mcp.tool()
def get_battery_info() -> dict:
    """Battery level, temperature, charging status từ /sys."""
    return {
        "capacity": read_sys("/sys/class/power_supply/battery/capacity"),
        "temp_celsius": int(read_sys("/sys/class/power_supply/battery/temp")) / 10,
        "status": read_sys("/sys/class/power_supply/battery/status"),
        "voltage_uv": read_sys("/sys/class/power_supply/battery/voltage_now"),
    }

@mcp.tool()
def get_thermal_zones() -> dict:
    """Nhiệt độ tất cả thermal zones."""

@mcp.tool()
def get_memory_info() -> dict:
    """RAM usage từ /proc/meminfo."""
```

Done: `openclaw ask "pin còn bao nhiêu và máy đang nóng không"` → trả lời chính xác.

**Thời gian ước tính:** 3–4 giờ

---

## Phase 4 — STT Server (Home)

**Mục tiêu:** whisper-live chạy trên home server với RTX 3060, accessible qua Tailscale.

### T4.1 — docker-compose.yml

```yaml
services:
  whisper-live:
    image: collabora/whisperlive:latest
    runtime: nvidia
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
      - WHISPER_MODEL=large-v3-turbo
      - LANGUAGE=vi
      - BACKEND=faster_whisper
      - DEVICE=cuda
    ports:
      - "9090:9090"
    volumes:
      - whisper-models:/root/.cache/huggingface
```

### T4.2 — config.yaml

```yaml
model: large-v3-turbo
language: vi
device: cuda
compute_type: float16
vad_filter: true
vad_threshold: 0.5
chunk_length_seconds: 5
```

### T4.3 — Test WebSocket

```python
# test_ws.py
import websocket, json
ws = websocket.create_connection("ws://homeserver:9090")
# Gửi audio chunk, nhận transcript
```

Done: Gửi file WAV tiếng Việt 10s → nhận transcript đúng trong < 3s.

**Thời gian ước tính:** 2–3 giờ

---

## Phase 5 — Android Assistant App (TimezAssistant)

**Mục tiêu:** App Android với wake word, real-time voice conversation, STT provider pluggable.

### T5.1 — Project Setup

**Gradle dependencies:**
```kotlin
// build.gradle.kts
dependencies {
    // Wake word
    implementation("ai.picovoice:porcupine-android:3.0.2")

    // STT on-device
    implementation("com.github.k2-fsa:sherpa-onnx-android:1.10.x")

    // VAD
    implementation("com.github.k2-fsa:sherpa-onnx-android:1.10.x")  // Silero bundled

    // WebSocket (WhisperLive + OpenClaw)
    implementation("com.squareup.okhttp3:okhttp:4.12.0")

    // Coroutines + Lifecycle
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.0")
    implementation("androidx.lifecycle:lifecycle-service:2.7.0")
}
```

Done: `./gradlew assembleDebug` thành công, APK install được.

### T5.2 — WakeWordService.kt

```
State: ACTIVE (listening) | PAUSED (battery < 20% or manual)

Logic:
  onCreate() → init Porcupine(keywordPath, sensitivity=0.5)
              → start AudioRecord (16kHz, mono, 512 samples/frame)
  onAudioFrame() → porcupine.process(frame)
                → if keyword detected → startVoiceSession()

Battery awareness:
  BroadcastReceiver(ACTION_BATTERY_CHANGED)
  if level < 20% → pauseListening(), notify user
  if level > 30% → resumeListening()

Notification: persistent "Đang lắng nghe..." với action Tắt
```

Done: Nói wake word → VoiceSessionService khởi động (thấy notification mới).

### T5.3 — STTProvider.kt (interface)

```kotlin
interface STTProvider {
    suspend fun startStream(onPartial: (String) -> Unit, onFinal: (String) -> Unit)
    suspend fun sendAudioChunk(pcm: ShortArray)
    suspend fun stopStream()
    fun isAvailable(): Boolean
}
```

**SherpaOnnxSTT.kt:**
```
Model download: lần đầu chạy, tải sherpa-onnx-zipformer-vi-30M-int8 (~31MB)
Streaming: OnlineRecognizer với chunk_size=[0,8,4]
VAD: SileroVad.isSpeech(frame) → chỉ gửi frames có tiếng
onEndpoint() → emit final transcript
```

**WhisperLiveSTT.kt:**
```
Connect: OkHttp WebSocket → ws://{settings.whisperLiveUrl}:9090
Protocol: gửi raw PCM 16kHz mono as binary frames
Receive: JSON {"text": "...", "type": "partial"|"final"}
Reconnect: exponential backoff 1s→2s→4s→8s (max)
```

Done: Nói "xin chào" → partial transcripts xuất hiện khi đang nói, final sau khi ngừng.

### T5.4 — SileroVAD.kt

```
Model: silero_vad.onnx (1.8MB, bundled trong assets/)
Input: 512 samples @ 16kHz
Output: speech probability [0.0, 1.0]
Threshold: 0.5 (configurable)
```

Done: Frames im lặng → prob < 0.3, frames có giọng → prob > 0.7.

### T5.5 — VoiceSessionService.kt

**State machine:**
```
IDLE
  ↓ wake word detected
LISTENING (foreground service, waveform overlay)
  ↓ VAD: user ngừng nói (silence > 800ms sau speech)
PROCESSING (spinner)
  ↓ STT final → gửi sang OpenClaw
SPEAKING (TTS playing response)
  ↓ TTS done
LISTENING  ← quay lại, chờ user nói tiếp

Exit conditions:
  - Silence > 8s trong LISTENING (không ai nói gì)
  - User nói "dừng lại" / "thoát" / "bye"
  - User nhấn nút End trên overlay
  - Battery < 15%
```

**Conversation context:** Mỗi session có `sessionId`, gửi kèm mọi message tới OpenClaw để Gateway giữ context.

Done: Nói → nhận trả lời → nói tiếp (3 lượt) mà không cần wake word lại. Nói "thoát" → session kết thúc.

### T5.6 — OpenClawModule.kt

```kotlin
class OpenClawModule(private val gatewayUrl: String) {
    // WebSocket connection tới OpenClaw Gateway
    // gatewayUrl = "ws://localhost:4000" (on-phone) hoặc Tailscale URL

    suspend fun sendMessage(text: String, sessionId: String): Flow<String> {
        // Gửi message, nhận streaming response
        // Emit từng chunk text khi Gateway stream về
    }

    fun isConnected(): Boolean
    suspend fun connect()
    suspend fun disconnect()
}
```

Done: `sendMessage("thời tiết hôm nay")` → stream text về, TTS đọc từng câu khi nhận đủ.

### T5.7 — TTSManager.kt

```kotlin
class TTSManager(context: Context) {
    private val tts = TextToSpeech(context) { ... }

    init {
        // Ưu tiên: Vietnamese voice nếu có
        // Fallback: default locale
        tts.language = Locale("vi", "VN")
    }

    // Sentence-boundary streaming: không đợi full response
    // Khi nhận "Hôm nay trời đẹp." → speak ngay, không đợi câu tiếp
    fun speakChunk(text: String)
    fun stop()
    fun isSpeaking(): Boolean
}
```

Done: TTS đọc tiếng Việt rõ ràng, bắt đầu đọc ngay khi câu đầu tiên đến (không đợi full response).

### T5.8 — VoiceOverlayView.kt

```
Floating overlay (SYSTEM_ALERT_WINDOW permission):
┌──────────────────────────┐
│  🎙️ Đang nghe...         │  ← state label
│  ████░░░░ waveform        │  ← audio level bar
│  "xin chào bạn..."       │  ← partial transcript
│                     [■]   │  ← End button
└──────────────────────────┘
Minimal: 120dp height, không block interaction
```

Done: Overlay xuất hiện khi session bắt đầu, biến mất khi kết thúc.

### T5.9 — SettingsActivity.kt

```
STT Provider:
  ○ SherpaOnnx (on-device, mặc định)
  ○ WhisperLive (home server)
    └── Server URL: [ws://192.168.1.x:9090]

OpenClaw Gateway:
  └── Gateway URL: [ws://localhost:4000]
  └── Token: [••••••••]

Wake Word:
  └── Sensitivity: [──●────] 0.5
  └── [Test wake word]

Battery Protection:
  ☑ Tắt wake word khi pin < 20%
  ☑ Giảm sensitivity khi pin < 40%
```

Done: Thay đổi STT provider → restart VoiceSessionService với provider mới.

**Thời gian ước tính Phase 5:** 10–14 giờ

---

## Dependencies giữa các Phase

```
P0 (Restructure)
 ├──→ P1 (Device Safety)    [song song với P2]
 ├──→ P2 (Gateway Termux)   [song song với P1]
 │     └──→ P3 (MCP Root)   [cần P2 xong trước]
 └──→ P4 (STT Server)       [độc lập, làm bất cứ lúc nào]

P5 (Android App):
  └── T5.1→T5.3: độc lập với P1/P2/P3
  └── T5.6 (OpenClaw Module): cần P2 (Gateway) xong
  └── T5.3 WhisperLive: cần P4 (STT Server) xong
  └── Integration test cuối: cần P2 + P3 + P4 + P5 đủ
```

---

## Tổng thời gian ước tính

| Phase | Nội dung | Giờ |
|-------|---------|-----|
| P0 | Restructure | 2 |
| P1 | Device Safety | 4 |
| P2 | Gateway Termux | 5 |
| P3 | MCP Root | 4 |
| P4 | STT Server | 3 |
| P5 | Android App | 12 |
| **Total** | | **~30 giờ** |

Có thể làm song song P1+P2 và P4+P5.T5.1–T5.5 của Android app không cần Gateway xong.

---

## Rủi ro và mitigation

| Rủi ro | Khả năng | Mitigation |
|--------|---------|------------|
| Termux bị Android kill Gateway | Cao | Wakelock + foreground service notification |
| Porcupine wake word accuracy thấp | Trung bình | Tune sensitivity, fallback nút hardware |
| SherpaOnnx Vietnamese model không đủ tốt | Trung bình | WhisperLive làm fallback dễ switch |
| whisper-live latency > 3s | Thấp (RTX3060+int8) | Giảm chunk size, dùng float16 |
| Magisk module conflict | Thấp | Test trên fresh LineageOS trước |
| OpenClaw Gateway API thay đổi | Trung bình | Pin `openclaw` version trong bootstrap.sh |

---

## Điều kiện hoàn thành toàn bộ project

1. Nói wake word → voice session khởi động trong < 1s
2. Nói câu tiếng Việt → transcript đúng (SherpaOnnx hoặc WhisperLive)
3. OpenClaw Gateway xử lý, stream response về
4. TTS bắt đầu đọc câu đầu trong < 2s sau khi người dùng ngừng nói
5. Có thể nói tiếp mà không cần wake word lại (persistent session)
6. Nói "thoát" → session kết thúc
7. Sau reboot phone: Gateway tự start, WakeWordService tự chạy
8. Battery > 45°C → alert notification xuất hiện
9. Settings: có thể switch STT provider không cần rebuild app
10. `openclaw ask "pin còn bao nhiêu"` → trả lời đúng qua MCP root tools
