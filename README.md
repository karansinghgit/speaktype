# SpeakType

<div align="center">

![SpeakType Icon](speaktype/Assets.xcassets/AppIcon.appiconset/icon_256x256.png)

**Fast, Offline Voice-to-Text for macOS**

![SpeakType app screenshot](image.png)
[![Download](https://img.shields.io/badge/Download-SpeakType.dmg-blueviolet?logo=apple&logoColor=white)](https://github.com/karansinghgit/speaktype/releases/latest)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2013.0+-blue?logo=apple)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/License-MIT-red)](LICENSE)

*Press a hotkey, speak, and instantly paste text anywhere on your Mac.*

</div>

---

## What is SpeakType?

SpeakType is a **privacy-first, offline voice dictation tool** for macOS. Unlike online dictation services, everything runs **100% locally** using OpenAI's Whisper AI model via [WhisperKit](https://github.com/argmaxinc/WhisperKit). Support for Parakeet coming soon!

- **Privacy First** - Zero data leaves your Mac
- **Lightning Fast** - Optimized for Apple Silicon
- **Works Everywhere** - Any app, any text field
- **Open Source** - Audit every line of code yourself

---

## Installation

### Requirements

- macOS 13.0+ (Ventura or newer)
- Apple Silicon (M1+) recommended
- 2GB available storage (for AI models)

### Download

**[Download Latest Release](https://github.com/karansinghgit/speaktype/releases/latest)**

1. Download `SpeakType.dmg`
2. Drag **SpeakType** to **Applications**
3. Grant Microphone + Accessibility + Documents Folder permissions
4. Download an AI model from Settings → AI Models

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

### Current Issues

⚠️ The first load of a freshly downloaded model runs a one-time CoreML/Neural Engine
optimization pass — around 30-60 seconds for small models and up to a few minutes for
large ones. The app shows a "First-time setup — optimizing model for your Mac" status
while this runs; macOS caches the result, so every later load takes seconds.

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
- [OpenAI Whisper](https://github.com/openai/whisper)

---

<div align="center">

**Made with ❤️ for developers**

*Privacy-first • Open Source *

</div>
