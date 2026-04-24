---
name: android-deps
type: reference
created: 2026-04-24
last-updated: 2026-04-24
---

# Android Dependencies (Gradle)

```kotlin
// Wake word
implementation("ai.picovoice:porcupine-android:3.0.2")

// STT on-device + VAD (Silero bundled)
implementation("com.github.k2-fsa.sherpa-onnx:sherpa-onnx-android:1.10.+")

// WebSocket (WhisperLive + OpenClaw Gateway)
implementation("com.squareup.okhttp3:okhttp:4.12.0")

// Coroutines + Lifecycle
implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.0")
implementation("androidx.lifecycle:lifecycle-service:2.7.0")
```

## SherpaOnnx Vietnamese model
File: `sherpa-onnx-zipformer-vi-30M-int8-2026-02-09`
Source: https://k2-fsa.github.io/sherpa/onnx/pretrained_models/offline-transducer/zipformer-transducer-models.html
Size: ~31MB int8 quantized
Download: on first launch, store in app assets or internal storage

## App package
`com.timezlab.assistant`
Min SDK: 26 (Android 8.0) — AudioRecord + foreground service
Target SDK: 34
