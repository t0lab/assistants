# Voice session persistent (multi-turn), không single-turn như Google Assistant

**Status:** accepted
**Date:** 2026-04-24

> **Amended 2026-05-29:** "OpenClaw" trong doc này nay đọc là "Hermes Agent" (pivot). Quyết định persistent multi-turn session vẫn giữ; Hermes cũng giữ context theo session. Đây là phase Android app (defer). Xem `hermes-agent-replaces-openclaw.md`.

## Context

Wake word assistants truyền thống (Google Assistant, Siri) hoạt động theo mô hình single-turn: wake word → một lệnh → kết quả → ngủ. User phải nói wake word lại cho mỗi lượt. OpenClaw hỗ trợ multi-turn conversation với context được giữ trong Gateway session.

## Decision

Sau khi wake word trigger, `VoiceSessionService` duy trì một phiên hội thoại liên tục. Sau khi TTS đọc xong response, app quay về LISTENING state và chờ user nói tiếp — không cần wake word lại. Session kết thúc khi: im lặng >8s, user nói "thoát"/"dừng lại", nhấn nút End, hoặc pin <15%.

OpenClaw Gateway giữ `sessionId` để duy trì context xuyên suốt phiên.

## Alternatives considered

- **Single-turn (Google Assistant model)** — rejected. Mỗi câu hỏi là independent request; không có context carry-over; cần nói wake word liên tục → annoying cho hội thoại tự nhiên.
- **Push-to-talk** — rejected. Cần tay để giữ nút; không tiện khi lái xe hoặc tay bận. Wake word hands-free là requirement.
- **Persistent always-on STT** — rejected. Tốn pin và RAM liên tục; SherpaOnnx/VAD chỉ active khi có speech, nhưng vẫn cần AudioRecord chạy. Sau session kết thúc phải trả về background wake-word-only mode.

## Consequences

**Better:**
- Hội thoại tự nhiên — không interrupt flow để nói wake word
- OpenClaw có context đầy đủ của conversation → trả lời thông minh hơn
- Trải nghiệm gần với Claude Voice / ChatGPT Voice hơn Google Assistant

**Worse:**
- Foreground service phải chạy suốt session → pin tốn hơn
- Cần state machine rõ ràng (IDLE/LISTENING/PROCESSING/SPEAKING) — phức tạp hơn single-turn
- Silence timeout 8s có thể quá ngắn hoặc quá dài tùy use case

**Must now be true:**
- `VoiceSessionService` là foreground service với persistent notification khi session active
- `sessionId` phải được tạo khi session bắt đầu và gửi kèm mọi message tới OpenClaw
- Mỗi session kết thúc phải gọi `releaseWakelock()` và trả về WakeWordService background mode
- Exit keyword detection chạy song song với STT — không phải post-processing

## Revisit if

User thường xuyên muốn hỏi một câu độc lập (không cần context) → thêm option "single-turn mode" trong Settings. Hoặc nếu pin drain quá cao trong persistent session → tunable timeout.
