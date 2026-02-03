# SpeakType

<div align="center">

![SpeakType Icon](speaktype/Assets.xcassets/AppIcon.appiconset/icon_256x256.png)

**Fast, Offline Voice-to-Text for macOS**

[![Download](https://img.shields.io/badge/Download-SpeakType.dmg-blueviolet?logo=apple&logoColor=white)](https://github.com/karansinghgit/speaktype/releases/download/v1.0.5/SpeakTypeVersion_1.0.0.dmg)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2013.0+-blue?logo=apple)](https://www.apple.com/macos/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-Native-green)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/License-MIT-red)](LICENSE)

*Press a hotkey, speak, and instantly paste text anywhere on your Mac.*

[Features](#features) • [Installation](#installation) • [Usage](#usage) • [Development](#development) • [Contributing](#contributing)

</div>

---

## 🎯 What is SpeakType?

SpeakType is a **privacy-first, offline voice dictation tool** for macOS that lets you type with your voice anywhere—in any app, at any time. Unlike online dictation services, everything runs **100% locally** on your Mac using OpenAI's Whisper AI model.

### Why SpeakType?

- 🔒 **Privacy First**: Zero data leaves your Mac—ever
- ⚡ **Lightning Fast**: Optimized for Apple Silicon
- 🌐 **Works Everywhere**: Any app, any text field
- 🎯 **Accurate**: Powered by OpenAI Whisper AI
- 💰 **Free & Open Source**: No subscriptions, no limits

---

✨ Features

### Core Features
- **🎤 System-Wide Dictation** - Works in Notes, Slack, Chrome, Terminal—anywhere
- **⌨️ Global Hotkey** - Press, speak, release = instant text (default: `fn` Function Key)
- **🔒 100% Offline** - All processing happens locally with WhisperKit
- **📋 Smart Paste** - Auto-copies to clipboard or pastes directly
- **🎨 Native macOS UI** - Beautiful SwiftUI interface with dark mode

### AI & Models
- **Multiple Models** - Choose between Base (fast) or Large (accurate)
- **Auto-Download** - One-click model downloads with progress tracking
- **Model Management** - Easy switching and cache cleanup
- **Optimized for Apple Silicon** - Best performance on M1/M2/M3 Macs

### User Experience
- **Mini Recorder** - Elegant floating recorder window
- **Visual Feedback** - Real-time audio waveforms and indicators
- **History** - Review past transcriptions
- **Customizable** - Configure hotkeys, audio devices, and behavior

---

## 🚀 Installation

### Requirements

| Component | Requirement |
|-----------|-------------|
| **OS** | macOS 13.0+ (Ventura or newer) |
| **Architecture** | Apple Silicon (M1+) recommended |
| **Storage** | 2GB free (for AI models) |
| **Permissions** | Microphone & Accessibility |

### Option 1: Download Pre-built App (Recommended)

**📥 [Download Latest Release](https://github.com/karansinghgit/speaktype/releases/latest)**

1. Download `SpeakType.dmg` from the latest release
2. Open the DMG file
3. Drag **SpeakType** to your **Applications** folder
4. **First time only:** Right-click the app → Select **"Open"** → Click **"Open"** again
   
   > ⚠️ **Why right-click?** This app is not yet notarized by Apple (requires paid developer account). Right-clicking bypasses Gatekeeper. This is safe - you can review the source code yourself!

5. Grant permissions when prompted (Microphone + Accessibility)
6. Download an AI model from Settings → AI Models

**That's it!** 🎉 Press `fn` (Function Key) to start dictating.

### Option 2: Build from Source

```bash
# 1. Clone the repository
git clone https://github.com/karansinghgit/speaktype.git
cd speaktype

# 2. Build & run
make build
make run

# Or open in Xcode
open speaktype.xcodeproj
```

### First Time Setup

1. **Grant Permissions** (you'll be prompted):
   - 🎤 Microphone access for recording
   - ♿ Accessibility access for auto-paste

2. **Download AI Model**:
   - Open SpeakType → AI Models
   - Click "Download" on Whisper Base (550MB)
   - Wait for download to complete

3. **Configure Hotkey** (optional):
   - Go to Settings
   - Default is `fn` (Function Key)
   - Customize to your preference

4. **Start Using**:
   - Press hotkey anywhere
   - Speak naturally
   - Release = text appears!

---

## 💡 Usage

### Basic Usage

```
1. Press hotkey (`fn`)
2. Speak your text
3. Release hotkey
4. ✨ Text appears!
```

### Examples

**Writing an Email**
```
Press hotkey → "Hi team comma I wanted to share the latest updates period"
→ "Hi team, I wanted to share the latest updates."
```

**Coding**
```
Press hotkey → "function calculate total open paren items close paren"
→ "function calculateTotal(items)"
```

**Quick Notes**
```
Press hotkey → "Remember to buy milk and eggs"
→ "Remember to buy milk and eggs"
```

### Pro Tips

- 💬 **Speak naturally** - Whisper handles accents and casual speech
- ⏱️ **Shorter is better** - Best results with 3-10 second clips
- 🎯 **Say punctuation** - "comma", "period", "question mark"
- 🔄 **Try again** - If transcription is off, just press hotkey again

---

## 🛠️ Development

### Quick Start for Development

```bash
# First time setup
make setup

# Clean development (removes all app data, permissions, caches)
make clean-dev

# Build and run
make build
open ~/Library/Developer/Xcode/DerivedData/speaktype-*/Build/Products/Debug/speaktype.app

# Or use the combined command
make run
```

**🧹 Fresh Start:** Use `make clean-dev` before each build to:
- Remove all app data and preferences
- Reset accessibility permissions
- Clear cached UI state
- Ensure you're testing the latest code

### Project Structure

```
speaktype/
├── App/                    # Application entry point
│   ├── speaktypeApp.swift
│   └── AppDelegate.swift
├── Views/                  # SwiftUI user interface
│   ├── Screens/           # Full-screen views
│   ├── Components/        # Reusable UI components
│   └── Overlays/          # Floating overlays
├── ViewModels/            # MVVM view models
├── Models/                # Data models
│   ├── AIModel.swift
│   ├── TranscriptionResult.swift
│   └── ...
├── Services/              # Business logic
│   ├── AudioRecordingService.swift
│   ├── WhisperService.swift
│   ├── ModelDownloadService.swift
│   └── ...
├── Controllers/           # Window management
├── Utilities/             # Helpers & extensions
│   ├── AppLogger.swift
│   ├── Constants.swift
│   └── Extensions/
└── Resources/             # Assets & config
    ├── Assets.xcassets/
    ├── Info.plist
    └── speaktype.entitlements
```

### Architecture

SpeakType follows **MVVM (Model-View-ViewModel)** pattern with clean separation:

- **Models**: Data structures (`AIModel`, `TranscriptionResult`)
- **Views**: SwiftUI UI components
- **ViewModels**: Business logic and state management  
- **Services**: Core functionality (audio, transcription, clipboard)

### Tech Stack

| Layer | Technology |
|-------|------------|
| **Language** | Swift 5.9+ |
| **UI** | SwiftUI + AppKit |
| **AI** | [WhisperKit](https://github.com/argmaxinc/WhisperKit) 0.9.4 |
| **Audio** | AVFoundation |
| **Hotkeys** | [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) |
| **State** | Combine + SwiftUI |

### Quick Commands

```bash
# Build & run
make build          # Build debug
make run            # Run app
make clean          # Clean build artifacts

# Distribution
make package        # Create ZIP for distribution
make dmg            # Create DMG installer
make release        # Create both ZIP and DMG

# Testing
make test           # Run all tests
make test-unit      # Unit tests only
make test-ui        # UI tests only

# Logging
make logs           # View live logs
make logs-errors    # Recent errors only
make logs-export    # Export to Desktop

# Code quality
make lint           # Run SwiftLint
make format         # Auto-fix issues
```

### Creating a Release

Want to publish a new version? It's automated!

```bash
# 1. Update version in Xcode project
# 2. Commit your changes
git add .
git commit -m "Release v1.0.0"

# 3. Create and push a tag
git tag v1.0.0
git push origin main
git push origin v1.0.0

# 4. GitHub Actions will automatically:
#    - Build the app
#    - Create a professional DMG with custom background
#    - Create ZIP package
#    - Create a GitHub release
#    - Upload the files
```

**Or build locally:**
```bash
# Install create-dmg first (one-time setup)
brew install create-dmg

# Build release
make release
# Files will be in dist/ folder with professional DMG installer
```

> 💡 **New!** The DMG installer now includes a custom background with drag-and-drop instructions for a professional installation experience. See [DMG_SETUP.md](DMG_SETUP.md) for details.

### Logging & Debugging

SpeakType uses Apple's **unified logging system** with categories:

```swift
// In your code
import Foundation

AppLogger.info("Started recording", category: .audio)
AppLogger.success("Transcription complete", category: .transcription)
AppLogger.error("Download failed", error: error, category: .models)
```

**View logs in terminal:**
```bash
# Live stream
make logs

# Filter by category
log stream --predicate 'process == "speaktype" AND category == "Transcription"'

# Export for debugging
make logs-export
```

---

## 🤝 Contributing

We welcome contributions! Here's how to get started:

### Quick Start for Contributors

1. **Fork & clone**
   ```bash
   git clone https://github.com/karansinghgit/speaktype.git
   cd speaktype
   ```

2. **Create a branch**
   ```bash
   git checkout -b feature/amazing-feature
   ```

3. **Make changes**
   - Follow SwiftUI best practices
   - Write tests for new features
   - Run `make lint` before committing

4. **Submit PR**
   ```bash
   git commit -m "Add amazing feature"
   git push origin feature/amazing-feature
   ```

### Code Guidelines

- ✅ Use MVVM pattern
- ✅ Write SwiftUI views, not UIKit
- ✅ Add unit tests for services
- ✅ Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- ✅ Use `AppLogger` instead of `print()`

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

---

## 🐛 Known Issues

### WhisperKit Dependency Warnings

You may see these build warnings:
```
warning: 'WhisperKit' is missing a dependency on 'TensorUtils'
warning: 'WhisperKit' is missing a dependency on 'Hub'
warning: 'WhisperKit' is missing a dependency on 'Tokenizers'
```

**These are harmless** and come from Xcode's dependency scanner analyzing WhisperKit's internal structure. They don't affect functionality—your app builds and runs perfectly. This is a limitation of WhisperKit 0.9.4, not your code.

---

## 🗺️ Roadmap

### Version 1.1 (Next)
- [ ] Streaming transcription (real-time)
- [ ] Multiple language support
- [ ] Custom vocabulary/terms
- [ ] Improved punctuation handling

### Version 1.2 (Future)
- [ ] Transcription history with search
- [ ] Text formatting commands
- [ ] Per-app custom hotkeys
- [ ] iCloud sync (optional)

### Version 2.0 (Vision)
- [ ] iOS companion app
- [ ] App Store release
- [ ] Advanced settings
- [ ] Plugin system

---

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

---

## 🙏 Credits & Acknowledgments

SpeakType is built with amazing open-source projects:

- **[WhisperKit](https://github.com/argmaxinc/WhisperKit)** by Argmax - Whisper models for macOS
- **[KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)** by Sindre Sorhus - Global hotkey management
- **[OpenAI Whisper](https://github.com/openai/whisper)** - State-of-the-art speech recognition

**Inspiration:**
- [VoiceInk](https://voices.ink/) - Original inspiration
- macOS Speech Framework - System dictation

---

## 📞 Support & Community

- **🐛 Bug Reports**: [GitHub Issues](https://github.com/karansinghgit/speaktype/issues)
- **💬 Discussions**: [GitHub Discussions](https://github.com/karansinghgit/speaktype/discussions)
- **📧 Email**: [your.email@example.com](mailto:your.email@example.com)

---

## ⭐ Star History

If you find SpeakType useful, please consider starring the repo!

---

<div align="center">

**Made with ❤️ by developers, for developers**

*Privacy-first • Open Source • Forever Free*

[⬆ Back to Top](#speaktype)

</div>
