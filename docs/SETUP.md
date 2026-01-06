# Setup Guide

This guide will help you set up the SpeakType development environment.

## Prerequisites

### Required

- **macOS**: 13.0 (Ventura) or later
- **Xcode**: 15.0 or later
- **Swift**: 5.9 or later (included with Xcode)
- **Git**: For version control

### Recommended

- **Homebrew**: Package manager for macOS
- **SwiftLint**: Code linting tool
- **Xcode Command Line Tools**: For terminal-based builds

## Initial Setup

### 1. Install Xcode

Download and install Xcode from the Mac App Store or Apple Developer website.

```bash
# Verify Xcode installation
xcode-select --version

# Install command line tools if needed
xcode-select --install
```

### 2. Install Homebrew (if not already installed)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 3. Install SwiftLint

```bash
brew install swiftlint
```

### 4. Clone the Repository

```bash
git clone <repository-url>
cd speaktype
```

### 5. Open the Project

```bash
# Open in Xcode
open speaktype.xcodeproj

# Or use the Makefile
make xcode
```

### 6. Build the Project

In Xcode:
- Select the `speaktype` scheme
- Choose your Mac as the destination
- Press `⌘B` to build

Or from the terminal:
```bash
make build
```

## Development Workflow

### Building

```bash
# Debug build
make build

# Release build
make build-release

# Clean build
make clean
```

### Running

```bash
# Run from terminal
make run

# Or press ⌘R in Xcode
```

### Testing

```bash
# Run all tests
make test

# Run unit tests only
make test-unit

# Run UI tests only
make test-ui

# Or press ⌘U in Xcode
```

### Linting

```bash
# Check for linting issues
make lint

# Auto-fix linting issues
make format
```

## Project Structure

After setup, your project structure should look like this:

```
speaktype/
├── .git/                       # Git repository
├── .gitignore                  # Git ignore rules
├── .swiftlint.yml             # SwiftLint configuration
├── .editorconfig              # Editor configuration
├── .gitattributes             # Git attributes
├── Makefile                    # Build automation
├── README.md                   # Project overview
├── CONTRIBUTING.md             # Contribution guidelines
├── speaktype.xcodeproj/       # Xcode project
├── speaktype/                  # Main source code
│   ├── App/                    # App entry point
│   ├── Views/                  # UI views
│   ├── ViewModels/             # View models
│   ├── Models/                 # Data models
│   ├── Services/               # Business logic
│   ├── Utilities/              # Helpers and extensions
│   └── Resources/              # Assets and resources
├── speaktypeTests/             # Unit tests
├── speaktypeUITests/           # UI tests
└── docs/                       # Documentation
```

## Configuration

### Xcode Settings

Recommended Xcode settings for development:

1. **Text Editing**:
   - Enable: "Automatically trim trailing whitespace"
   - Enable: "Including whitespace-only lines"
   - Tab width: 4 spaces
   - Indent width: 4 spaces
   - Use spaces instead of tabs

2. **Source Control**:
   - Enable: "Enable source control"
   - Enable: "Refresh local status automatically"

3. **Build Settings**:
   - Swift Language Version: Swift 5
   - Optimization Level (Debug): -Onone
   - Optimization Level (Release): -O

### SwiftLint Integration

SwiftLint is configured via `.swiftlint.yml`. To integrate with Xcode:

1. Open Xcode project
2. Select the target
3. Go to Build Phases
4. Add a new "Run Script Phase"
5. Add this script:

```bash
if which swiftlint >/dev/null; then
  swiftlint
else
  echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
fi
```

## Troubleshooting

### Build Errors

**Problem**: "No such module" errors

**Solution**:
```bash
# Clean build folder
make clean

# Or in Xcode: Product > Clean Build Folder (⇧⌘K)
```

**Problem**: SwiftLint warnings/errors

**Solution**:
```bash
# Auto-fix issues
make format

# Or manually fix based on warnings
```

### Git Issues

**Problem**: Line ending issues

**Solution**: The project uses `.gitattributes` to normalize line endings. Ensure you have:
```bash
git config --global core.autocrlf input
```

**Problem**: Merge conflicts in `.pbxproj`

**Solution**: The `.gitattributes` file is configured to use `merge=union` for project files, which helps reduce conflicts.

### Xcode Issues

**Problem**: Xcode not finding files

**Solution**:
1. Clean build folder (⇧⌘K)
2. Close Xcode
3. Delete DerivedData:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
4. Reopen project

**Problem**: Simulator issues

**Solution**:
```bash
# Reset simulator
xcrun simctl erase all

# Or use Xcode: Device > Erase All Content and Settings
```

## IDE Setup

### Xcode Extensions

Recommended Xcode extensions:
- **SwiftLint for Xcode**: Real-time linting
- **Xcode Themes**: Better color schemes

### VS Code (Optional)

If you prefer VS Code for editing:

1. Install Swift extension
2. Install SwiftLint extension
3. Open workspace: `code .`

`.editorconfig` is already configured for consistent formatting.

## Environment Variables

If your app requires environment variables:

1. Create a `.env` file (ignored by git):
   ```bash
   API_KEY=your_api_key_here
   BASE_URL=https://api.example.com
   ```

2. Add to Xcode scheme:
   - Edit Scheme > Run > Arguments
   - Add environment variables

## Next Steps

After setup:

1. Read [ARCHITECTURE.md](ARCHITECTURE.md) to understand the project structure
2. Read [FOLDER_STRUCTURE.md](FOLDER_STRUCTURE.md) for organization guidelines
3. Read [CONTRIBUTING.md](../CONTRIBUTING.md) before making changes
4. Run tests to ensure everything works: `make test`
5. Start coding! 🚀

## Additional Resources

- [Swift Documentation](https://swift.org/documentation/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- [Xcode Documentation](https://developer.apple.com/documentation/xcode)
- [Git Documentation](https://git-scm.com/doc)

## Getting Help

If you encounter issues:

1. Check this documentation
2. Search existing issues on GitHub
3. Ask in team chat/Slack
4. Create a new issue with details

## License

[Add your license information here]

