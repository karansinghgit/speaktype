# SpeakType

> Fast, offline voice-to-text for macOS. Press a hotkey, speak, and instantly paste text anywhere.

[![Swift](https://img.shields.io/badge/Swift-5.9-orange)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2013.0+-blue)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

## Features

- 🎤 **System-wide voice dictation** - Works in any app
- ⚡ **Fast & offline** - Powered by WhisperKit (local AI)
- ⌨️ **Global hotkey** - Press, speak, release = instant text
- 🔒 **Privacy-first** - Everything runs locally, no data leaves your Mac
- 🎨 **Native macOS UI** - Built with SwiftUI
- 📋 **Auto-paste** - Copies to clipboard or pastes directly

## Installation

### Requirements

- macOS 13.0+ (Ventura or later)
- Apple Silicon Mac recommended (for best Whisper performance)

###Clone & Build

```bash
git clone https://github.com/yourusername/speaktype.git
cd speaktype
make build
```

Or open `speaktype.xcodeproj` in Xcode and press ⌘R.

## Quick Start

1. **Grant permissions** - Microphone and Accessibility access (required for auto-paste)
2. **Download a model** - Go to AI Models tab and download Whisper Base (550MB)
3. **Set your hotkey** - Default is `⌥ + Space` (Option + Space)
4. **Start using** - Press hotkey, speak, release = text!

## Usage

```
Press hotkey → Speak → Release → Text appears!
```

- **In any app**: Works in Notes, Slack, Chrome, Terminal, anywhere
- **Any text field**: Messages, emails, code comments, search bars
- **Long or short**: From single words to paragraphs

## Development

### Quick Commands

```bash
make build         # Build the project
make run           # Run the app
make test          # Run tests
make logs          # View live logs
make logs-export   # Export logs for debugging
make clean         # Clean build artifacts
```

### Project Structure

```
speaktype/
├── App/           # App entry point
├── Views/         # SwiftUI views
├── Models/        # Data models
├── Services/      # Audio, transcription, clipboard
├── Controllers/   # Window management
└── Utilities/     # Helpers and extensions
```

### Logging

```bash
# View live logs during development
make logs

# View recent errors
make logs-errors

# Export logs for bug reports
make logs-export
```

The app uses Apple's unified logging system with categories:
```swift
AppLogger.info("Starting transcription", category: .transcription)
AppLogger.error("Download failed", error: error, category: .models)
```

## Architecture

- **MVVM Pattern** - Clean separation of concerns
- **SwiftUI** - Modern, declarative UI
- **WhisperKit** - Local AI for speech recognition
- **Combine** - Reactive state management
- **AVFoundation** - Audio recording

### Key Services

- `AudioRecordingService` - Handles microphone input
- `WhisperService` - Manages AI transcription
- `ClipboardService` - Clipboard & paste operations
- `ModelDownloadService` - Downloads and manages AI models
- `PermissionService` - System permission handling

## Known Issues

### WhisperKit Dependency Warnings

You may see these warnings during build:
```
warning: 'WhisperKit' is missing a dependency on 'TensorUtils'
warning: 'WhisperKit' is missing a dependency on 'Hub'
warning: 'WhisperKit' is missing a dependency on 'Tokenizers'
```

**These are harmless** and come from Xcode's dependency scanner. They don't affect functionality - the app builds and runs correctly. This is a limitation of WhisperKit 0.9.4 itself, not your project.

## Contributing

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

## Tech Stack

- **Swift 5.9+** - Modern, type-safe language
- **SwiftUI** - Declarative UI framework
- **WhisperKit 0.9.4** - OpenAI Whisper models for macOS
- **KeyboardShortcuts** - Global hotkey management
- **AVFoundation** - Audio capture and processing

## Roadmap

- [ ] Multiple language support
- [ ] Streaming transcription (real-time)
- [ ] Custom vocabulary/terms
- [ ] Transcription history
- [ ] Text formatting commands
- [ ] iOS companion app

## License

[Add your license here - MIT recommended for open source]

## Credits

- Built with [WhisperKit](https://github.com/argmaxinc/WhisperKit) by Argmax
- Inspired by [VoiceInk](https://voices.ink/)
- Uses [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) by Sindre Sorhus

## Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/speaktype/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/speaktype/discussions)

---

Made with ❤️ for the Mac community
