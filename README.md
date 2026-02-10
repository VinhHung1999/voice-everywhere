# VoiceEverywhere

A native macOS menubar app that lets you **type with your voice** in any text field. Press a hotkey, speak, and your words appear wherever your cursor is — no copy-paste needed. Supports real-time Vietnamese and English recognition with automatic language detection.

## Features

- **Real-time speech-to-text** via Soniox API (`stt-rt-v3` model)
- **Works everywhere** — types directly into any focused app using the Accessibility API
- **Bilingual** — auto-detects Vietnamese and English
- **Speaker verification** — enroll your voice and filter out other speakers (ECAPA-TDNN)
- **LLM post-processing** — optionally rewrite, translate, or format text via xAI API before typing
- **Format presets** — save and switch between named instruction sets (e.g. "Formal English", "Meeting Notes")
- **Global hotkey** — `Ctrl + Option + Space` to toggle recording from anywhere
- **Menubar-only** — lightweight, no dock icon, runs quietly in the background

## Requirements

- macOS 13+
- Xcode Command Line Tools (`xcode-select --install`)
- [Soniox](https://soniox.com) API key

## Quick Start

```bash
git clone git@github.com:VinhHung1999/voice-everywhere.git
cd voice-everywhere

# Build the app
./scripts/build_app.sh

# Launch
open dist/VoiceEverywhere.app
```

Or download the latest release from [Releases](https://github.com/VinhHung1999/voice-everywhere/releases).

## Usage

1. Click the **mic icon** in the menubar or press `Ctrl + Option + Space` to start recording
2. Speak — text is recognized in real-time and typed into the focused text field
3. Press `Ctrl + Option + Space` again to stop

### Menubar Status Icons

| Icon | State |
|------|-------|
| `mic` | Ready |
| `mic.fill` | Recording |
| `mic.badge.xmark` | Connecting / Error |

## Configuration

Click the mic icon in the menubar → **Settings** to open the configuration window.

### Speech-to-Text (Soniox)

| Setting | Description |
|---------|-------------|
| **API Key** | Your Soniox API key (required) |
| **Context Terms** | Comma-separated terms for better recognition (e.g. `SwiftUI, Soniox, CoreML`) |
| **General Context** | Free-text context description (e.g. `iOS development meeting`) |

### Speaker Verification

| Setting | Description |
|---------|-------------|
| **Enable** | Toggle speaker verification on/off |
| **Enroll** | Record 3–5 voice samples to create your voice profile |
| **Threshold** | Adjust verification sensitivity (default: 0.25) |

When enabled, only your voice is transcribed — other speakers are filtered out in real-time.

### LLM Post-Processing (xAI)

Enable **LLM post-processing** to have recognized text refined by an LLM before typing.

| Setting | Description |
|---------|-------------|
| **xAI API Key** | Your xAI API key |
| **Model** | LLM model (default: `grok-3-mini-fast`) |
| **Output Language** | English, Vietnamese, or "As spoken (no LLM)" |
| **Format Preset** | Select a preset with custom formatting instructions |

Use **+** / **−** / **Edit** to manage format presets. Select **(None)** to disable.

## Permissions

The app requires two macOS permissions:

1. **Microphone** — prompted on first launch. If denied: System Settings → Privacy & Security → Microphone
2. **Accessibility** — required for typing into other apps. System Settings → Privacy & Security → Accessibility → enable VoiceEverywhere

## Architecture

```
Hotkey → AudioCapture (16kHz PCM) → SonioxStreamer (WebSocket) → recognized text
                                          ↓
                            [optional] SpeakerVerifier (ECAPA-TDNN)
                                          ↓
                            [optional] LLMProcessor (xAI API)
                                          ↓
                                    TextInjector (CGEvent)
                                          ↓
                                    focused text field
```

Built with Swift/SwiftUI as a single SwiftPM executable — no Xcode project required.

| Module | Purpose |
|--------|---------|
| `AppDelegate` | Menubar UI (NSStatusItem) |
| `VoiceController` | State machine & orchestration |
| `AudioCapture` | AVAudioEngine → 16kHz mono PCM |
| `SonioxStreamer` | WebSocket client for Soniox RT API |
| `SpeakerVerifier` | Speaker verification via Python service |
| `LLMProcessor` | xAI API client for post-processing |
| `TextInjector` | Accessibility API keyboard simulation |
| `HotKeyManager` | Global hotkey via Carbon framework |

## Building

```bash
# Release build (creates dist/VoiceEverywhere.app)
./scripts/build_app.sh

# Debug build
./scripts/build_app.sh debug

# Direct Swift build (no app bundle)
swift build -c release
```

## License

MIT
