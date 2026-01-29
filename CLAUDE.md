# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

VoiceEverywhere is a native macOS menubar application (Swift/SwiftUI) that captures voice input and converts it to text in real-time using the Soniox speech-to-text API, then types the recognized text into any focused text field via the Accessibility API. Supports Vietnamese and English language identification. The app runs as a menubar-only app (no dock icon) with inline settings for API key and recognition context configuration.

## Build & Run Commands

```bash
# Build release (creates dist/VoiceEverywhere.app)
./scripts/build_app.sh

# Build debug
./scripts/build_app.sh debug

# Run the app
open dist/VoiceEverywhere.app

# Direct Swift build (without app bundle)
swift build -c release
swift build              # debug
```

There are no test targets configured.

## Architecture

All source code lives in `Sources/` (single SwiftPM executable target, no external dependencies). Linked framework: Carbon (for global hotkey).

**Data flow:** Hotkey press → AudioCapture (16kHz PCM via AVAudioEngine) → SonioxStreamer (WebSocket to `wss://stt-rt.soniox.com/transcribe-websocket`) → recognized text → TextInjector (CGEvent keyboard simulation into focused app)

**Key modules:**

- **AppMain.swift** — SwiftUI `@main` entry point with empty Settings scene (menubar-only app)
- **AppDelegate.swift** — Menubar UI (NSStatusItem with mic/mic.fill/mic.badge.xmark icons), state display, error alerts, API key validation before starting, embeds MenuSettingsView
- **VoiceController.swift** — State machine (`idle → connecting → listening → finishing → idle | error`) and orchestration; coordinates AudioCapture, SonioxStreamer, and TextInjector; manages activity token to prevent system sleep during recording; plays sound feedback (Tink on start, Blow on stop)
- **SonioxStreamer.swift** — WebSocket client implementing Soniox RTv3 streaming protocol; handles partial/final token responses; supports optional context (terms + general text) in config message
- **AudioCapture.swift** — AVAudioEngine setup, format conversion (native → 16kHz mono PCM s16le), mic permission handling
- **HotKeyManager.swift** — Global hotkey registration via Carbon framework (Ctrl+Option+Space)
- **TextInjector.swift** — Accessibility API keyboard simulation to type text into any app; checks AXIsProcessTrusted before injecting
- **ContextConfigWindow.swift** — Contains `MenuSettingsView`: inline settings panel embedded in menubar menu with API key (secure field), context terms (comma-separated), and general context text inputs; persists to UserDefaults
- **Logger.swift** — Async file logging to `~/Library/Logs/VoiceEverywhere.log` with ISO8601 timestamps

## Configuration

The app stores settings in **UserDefaults**:

| Key | Description |
|-----|-------------|
| `soniox_api_key` | Soniox API authentication key |
| `soniox_context_terms` | Comma-separated special terms for recognition (e.g. "SwiftUI, Soniox, CoreML") |
| `soniox_context_general` | General context text to improve recognition accuracy |

All three are configured via the inline MenuSettingsView in the menubar menu and read at recording start.

## Required macOS Permissions

1. **Microphone Access** — prompted on first run
2. **Accessibility** — required for TextInjector to simulate keyboard input (System Settings → Privacy & Security → Accessibility)

## Key Technical Details

- **Platform:** macOS 13+ (Swift Tools 6.1)
- **Soniox model:** `stt-rt-v3` with language hints `["vi", "en"]` and language identification enabled
- **Soniox context:** Optional terms array and general text passed in WebSocket config for improved recognition
- **Audio format:** PCM signed 16-bit LE, 16kHz, mono
- **Default hotkey:** Ctrl+Option+Space (⌃⌥Space) — toggles recording on/off
- **Bundle ID:** `com.local.voiceeverywhere`
- **App type:** LSUIElement (menubar-only, no dock icon)
- **Sleep prevention:** Uses ProcessInfo.beginActivity() during recording
- **Sound feedback:** Tink on start, Blow on stop
