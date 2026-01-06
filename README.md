# SpeakType

A modern macOS application built with SwiftUI.

## Project Structure

```
speaktype/
├── speaktype/                  # Main application target
│   ├── App/                    # Application entry point and configuration
│   ├── Views/                  # SwiftUI views and UI components
│   ├── ViewModels/             # View models and business logic
│   ├── Models/                 # Data models and entities
│   ├── Services/               # Business logic and API services
│   ├── Utilities/              # Helper functions and extensions
│   ├── Resources/              # Non-code resources
│   │   └── Assets.xcassets/   # Images, colors, and other assets
│   └── Supporting Files/       # Info.plist, entitlements, etc.
├── speaktypeTests/             # Unit tests
├── speaktypeUITests/           # UI tests
└── docs/                       # Documentation
```

## Requirements

- macOS 13.0+
- Xcode 15.0+
- Swift 5.9+

## Getting Started

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd speaktype
```

2. Open the project in Xcode:
```bash
open speaktype.xcodeproj
```

3. Build and run the project (⌘R)

### Development

- Follow the [Contributing Guidelines](CONTRIBUTING.md) when making changes
- Use SwiftUI for all UI components
- Follow Swift naming conventions and style guide
- Write unit tests for business logic
- Write UI tests for critical user flows

## Architecture

This project follows the MVVM (Model-View-ViewModel) architecture pattern:

- **Models**: Data structures and business entities
- **Views**: SwiftUI views that display data
- **ViewModels**: Manage view state and handle user interactions
- **Services**: Handle data persistence, networking, and other business logic

## Building

### Debug Build
```bash
xcodebuild -scheme speaktype -configuration Debug
```

### Release Build
```bash
xcodebuild -scheme speaktype -configuration Release
```

## Testing

### Run Unit Tests
```bash
xcodebuild test -scheme speaktype -destination 'platform=macOS'
```

### Run UI Tests
```bash
xcodebuild test -scheme speaktype -destination 'platform=macOS' -only-testing:speaktypeUITests
```

## Code Style

- Use SwiftLint for code linting (configuration in `.swiftlint.yml`)
- Follow Apple's Swift API Design Guidelines
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions small and focused

## License

[Add your license here]

## Contact

[Add contact information here]

