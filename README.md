# SpeakType

<div align="center">

![SpeakType Icon](speaktype/Assets.xcassets/AppIcon.appiconset/icon_256x256.png)

**Fast, Offline Voice-to-Text for macOS**

[![Download](https://img.shields.io/badge/Download-SpeakType.dmg-blueviolet?logo=apple&logoColor=white)](https://github.com/karansinghgit/speaktype/releases/latest)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2013.0+-blue?logo=apple)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/License-MIT-red)](LICENSE)

*Press a hotkey, speak, and instantly paste text anywhere on your Mac.*

</div>

---

## What is SpeakType?

SpeakType is a **privacy-first, offline voice dictation tool** for macOS. Unlike online dictation services, everything runs **100% locally** using OpenAI's Whisper AI model via [WhisperKit](https://github.com/argmaxinc/WhisperKit).

- **Privacy First** - Zero data leaves your Mac
- **Lightning Fast** - Optimized for Apple Silicon
- **Works Everywhere** - Any app, any text field
- **Free & Open Source** - No subscriptions, no limits

---

## Installation

### Requirements

- macOS 13.0+ (Ventura or newer)
- Apple Silicon (M1+) recommended
- 2GB free storage (for AI models)

### Download

**[Download Latest Release](https://github.com/karansinghgit/speaktype/releases/latest)**

1. Download `SpeakType.dmg`
2. Drag **SpeakType** to **Applications**
3. Right-click → **Open** (required for unsigned apps)
4. Grant Microphone + Accessibility permissions
5. Download an AI model from Settings → AI Models

Press `fn` to start dictating.

### Build from Source

```bash
git clone https://github.com/karansinghgit/speaktype.git
cd speaktype
make build && make run
```

---

## Usage

1. Press hotkey (`fn` by default)
2. Speak your text
3. Release hotkey
4. Text appears!

**Tips:**
- Speak naturally - Whisper handles accents well
- Say punctuation: "comma", "period", "question mark"
- Best results with 3-10 second clips

---

## Development

```bash
make build          # Build debug
make run            # Run app
make clean          # Clean build
make test           # Run tests
make dmg            # Create DMG installer
```

### Release

```bash
scripts/release.sh 1.0.6
git push origin HEAD
git push origin v1.0.6
```

### Project Structure

```
speaktype/
├── App/           # Entry point
├── Views/         # SwiftUI interface
├── Models/        # Data models
├── Services/      # Core functionality
├── Controllers/   # Window management
└── Resources/     # Assets & config
```

### Tech Stack

- **Swift 5.9+** / SwiftUI + AppKit
- **[WhisperKit](https://github.com/argmaxinc/WhisperKit)** - Local Whisper inference
- **[KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)** - Global hotkeys
- **AVFoundation** - Audio capture

---

## Contributing

1. Fork & clone
2. Create a branch: `git checkout -b feature/my-feature`
3. Make changes and run `make lint`
4. Submit a PR

---

## License

MIT License - see [LICENSE](LICENSE) for details.

---

## Credits

- [WhisperKit](https://github.com/argmaxinc/WhisperKit) by Argmax
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) by Sindre Sorhus
- [OpenAI Whisper](https://github.com/openai/whisper)

---

<div align="center">

**Made with ❤️ for developers**

*Privacy-first • Open Source • Forever Free*

</div>
