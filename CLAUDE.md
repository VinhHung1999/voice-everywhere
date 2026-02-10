# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Memory
[Memory](.claude/memory/README.md)

## Project Overview

VoiceEverywhere is a native macOS menubar application (Swift/SwiftUI) that captures voice input and converts it to text in real-time using the Soniox speech-to-text API, then types the recognized text into any focused text field via the Accessibility API. Supports Vietnamese and English language identification. Optional LLM post-processing via xAI API can rewrite/translate/format the recognized text before typing. The app runs as a menubar-only app (no dock icon) with a Settings window for API keys, context, and format presets.

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

**Data flow:** Hotkey press → AudioCapture (16kHz PCM via AVAudioEngine) → SonioxStreamer (WebSocket to `wss://stt-rt.soniox.com/transcribe-websocket`) → recognized text → (optional) LLMProcessor (xAI API post-processing) → TextInjector (CGEvent keyboard simulation into focused app)

**Key modules:**

- **AppMain.swift** — SwiftUI `@main` entry point with empty Settings scene (menubar-only app)
- **AppDelegate.swift** — Menubar UI (NSStatusItem with mic/mic.fill/mic.badge.xmark icons), state display, error alerts, API key validation before starting, embeds MenuSettingsView
- **VoiceController.swift** — State machine (`idle → connecting → listening → finishing → idle | error`) and orchestration; coordinates AudioCapture, SonioxStreamer, and TextInjector; manages activity token to prevent system sleep during recording; plays sound feedback (Tink on start, Blow on stop)
- **SonioxStreamer.swift** — WebSocket client implementing Soniox RTv3 streaming protocol; handles partial/final token responses; supports optional context (terms + general text) in config message
- **AudioCapture.swift** — AVAudioEngine setup, format conversion (native → 16kHz mono PCM s16le), mic permission handling
- **HotKeyManager.swift** — Global hotkey registration via Carbon framework (Ctrl+Option+Space)
- **TextInjector.swift** — Accessibility API keyboard simulation to type text into any app; checks AXIsProcessTrusted before injecting
- **LLMProcessor.swift** — xAI API client for optional post-processing of recognized text; reads config from UserDefaults (API key, model, output language, active format preset); includes `FormatPreset` Codable struct
- **ContextConfigWindow.swift** — `SettingsWindowController` + `SettingsContentView`: Settings window with Soniox config (API key, context terms, general context), LLM config (toggle, xAI key, model, output language), and format preset management (dropdown + add/remove/edit buttons); persists to UserDefaults
- **Logger.swift** — Async file logging to `~/Library/Logs/VoiceEverywhere.log` with ISO8601 timestamps

## Configuration

The app stores settings in **UserDefaults**:

| Key | Description |
|-----|-------------|
| `soniox_api_key` | Soniox API authentication key |
| `soniox_context_terms` | Comma-separated special terms for recognition (e.g. "SwiftUI, Soniox, CoreML") |
| `soniox_context_general` | General context text to improve recognition accuracy |
| `llm_enabled` | Bool — whether LLM post-processing is active |
| `xai_api_key` | xAI API authentication key |
| `xai_model` | LLM model name (default: `grok-3-mini-fast`) |
| `output_language` | Output language: "English", "Vietnamese", or "As spoken (no LLM)" |
| `format_presets` | JSON-encoded array of `{name, instructions}` format presets |
| `active_format_preset` | Name of the currently selected format preset (empty = none) |

All settings are configured via the Settings window (menubar → Settings) and read at recording start.

## Required macOS Permissions

1. **Microphone Access** — prompted on first run
2. **Accessibility** — required for TextInjector to simulate keyboard input (System Settings → Privacy & Security → Accessibility)

## Key Technical Details

- **Platform:** macOS 13+ (Swift Tools 6.1)
- **Soniox model:** `stt-rt-v3` with language hints `["vi", "en"]` and language identification enabled
- **Soniox context:** Optional terms array and general text passed in WebSocket config for improved recognition
- **LLM post-processing:** Optional xAI API integration; supports format presets (named instruction sets stored as JSON in UserDefaults)
- **Audio format:** PCM signed 16-bit LE, 16kHz, mono
- **Default hotkey:** Ctrl+Option+Space (⌃⌥Space) — toggles recording on/off
- **Bundle ID:** `com.local.voiceeverywhere`
- **App type:** LSUIElement (menubar-only, no dock icon)
- **Sleep prevention:** Uses ProcessInfo.beginActivity() during recording
- **Sound feedback:** Tink on start, Blow on stop

## Project Memory

Project memories are stored in `.claude/memory/`. Use `--project-recall` before complex tasks, `--project-store` after meaningful work.

| Topic | Content |
|-------|---------|
| [bugs-and-lessons](.claude/memory/bugs-and-lessons/README.md) | Bugs encountered, root causes, fixes, and lessons learned |
| [sprint-history](.claude/memory/sprint-history/README.md) | Sprint summaries, delivered features, team velocity |
| [team](.claude/memory/team/README.md) | Team roles, workflow, collaboration patterns |
| [design-decisions](.claude/memory/design-decisions/README.md) | UI/UX decisions, design rationale, interaction patterns |
| [api-design](.claude/memory/api-design/README.md) | API endpoints, protocols, integration patterns |
| [architecture](.claude/memory/architecture/README.md) | System structure, module boundaries, key architectural patterns |
