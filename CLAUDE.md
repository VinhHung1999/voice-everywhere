# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

VoiceEverywhere is a native macOS menubar application (Swift/SwiftUI) that captures voice input and converts it to text in real-time using the Soniox speech-to-text API, then types the recognized text into any focused text field via the Accessibility API. Supports Vietnamese and English language identification.

## Build & Run Commands

```bash
# Build release (creates dist/VoiceEverywhere.app)
./scripts/build_app.sh

# Build debug
./scripts/build_app.sh debug

# Run the app (requires SONIOX_API_KEY env var or ~/.voiceeverywhere_api_key file)
export SONIOX_API_KEY="your_key"
open dist/VoiceEverywhere.app

# Direct Swift build (without app bundle)
swift build -c release
swift build              # debug
```

There are no test targets configured.

## Architecture

All source code lives in `Sources/` (single SwiftPM executable target, no external dependencies).

**Data flow:** Hotkey press → AudioCapture (16kHz PCM via AVAudioEngine) → SonioxStreamer (WebSocket to `wss://stt-rt.soniox.com`) → recognized text → TextInjector (CGEvent keyboard simulation into focused app)

**Key modules:**

- **AppMain.swift** — SwiftUI `@main` entry point
- **AppDelegate.swift** — Menubar UI (NSStatusItem), state display, error alerts
- **VoiceController.swift** — State machine (`idle → connecting → listening → finishing → idle`) and orchestration; coordinates AudioCapture, SonioxStreamer, and TextInjector
- **SonioxStreamer.swift** — WebSocket client implementing Soniox RTv3 streaming protocol; handles partial/final token responses
- **AudioCapture.swift** — AVAudioEngine setup, format conversion, mic permission handling
- **HotKeyManager.swift** — Global hotkey registration via Carbon framework (Ctrl+Option+Space)
- **TextInjector.swift** — Accessibility API keyboard simulation to type text into any app
- **Logger.swift** — Async file logging to `~/Library/Logs/VoiceEverywhere.log`

## Required macOS Permissions

1. **Microphone Access** — prompted on first run
2. **Accessibility** — required for TextInjector to simulate keyboard input (System Settings → Privacy & Security → Accessibility)

## Key Technical Details

- **Platform:** macOS 13+ (Swift Tools 6.1)
- **Soniox model:** `stt-rt-v3` with language hints `["vi", "en"]`
- **Audio format:** PCM signed 16-bit LE, 16kHz, mono
- **Default hotkey:** Ctrl+Option+Space (⌃⌥Space) — toggles recording on/off
- **API key:** loaded from `SONIOX_API_KEY` env var or `~/.voiceeverywhere_api_key` file
- **Bundle ID:** `com.local.voiceeverywhere`
