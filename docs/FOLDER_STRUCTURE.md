# Folder Structure Guidelines

This document outlines the folder structure and organization guidelines for the SpeakType macOS application.

## Project Root Structure

```
speaktype/
├── .git/                       # Git repository
├── .gitignore                  # Git ignore rules
├── .swiftlint.yml             # SwiftLint configuration
├── README.md                   # Project overview
├── CONTRIBUTING.md             # Contribution guidelines
├── speaktype.xcodeproj/       # Xcode project file
├── speaktype/                  # Main application source
├── speaktypeTests/             # Unit tests
├── speaktypeUITests/           # UI tests
└── docs/                       # Documentation
```

## Main Application Structure (`speaktype/`)

```
speaktype/
├── App/
│   ├── speaktypeApp.swift              # App entry point
│   └── AppDelegate.swift                # App delegate (if needed for AppKit)
│
├── Views/
│   ├── ContentView.swift                # Main content view
│   ├── Screens/                         # Full-screen views
│   │   ├── HomeScreen.swift
│   │   ├── SettingsScreen.swift
│   │   └── ...
│   └── Components/                      # Reusable UI components
│       ├── Buttons/
│       │   ├── PrimaryButton.swift
│       │   └── SecondaryButton.swift
│       ├── Cards/
│       │   └── InfoCard.swift
│       └── ...
│
├── ViewModels/
│   ├── HomeViewModel.swift
│   ├── SettingsViewModel.swift
│   └── ...
│
├── Models/
│   ├── User.swift
│   ├── Settings.swift
│   └── ...
│
├── Services/
│   ├── Network/
│   │   ├── NetworkManager.swift
│   │   ├── APIEndpoint.swift
│   │   └── NetworkError.swift
│   ├── Storage/
│   │   ├── UserDefaultsManager.swift
│   │   ├── KeychainManager.swift
│   │   └── FileManager+Extensions.swift
│   └── ...
│
├── Utilities/
│   ├── Constants.swift
│   ├── Extensions/
│   │   ├── View+Extensions.swift
│   │   ├── Color+Extensions.swift
│   │   ├── String+Extensions.swift
│   │   └── ...
│   └── Helpers/
│       ├── DateFormatter+Helpers.swift
│       ├── ValidationHelpers.swift
│       └── ...
│
└── Resources/
    ├── Assets.xcassets/                 # Images, colors, icons
    │   ├── AppIcon.appiconset/
    │   ├── AccentColor.colorset/
    │   ├── Images/
    │   └── Colors/
    ├── Localizable.strings              # Localization strings
    ├── Info.plist                       # App configuration
    └── speaktype.entitlements          # App entitlements
```

## Testing Structure

### Unit Tests (`speaktypeTests/`)

```
speaktypeTests/
├── ViewModelTests/
│   ├── HomeViewModelTests.swift
│   └── SettingsViewModelTests.swift
├── ModelTests/
│   ├── UserTests.swift
│   └── SettingsTests.swift
├── ServiceTests/
│   ├── NetworkManagerTests.swift
│   └── StorageManagerTests.swift
├── Mocks/
│   ├── MockNetworkManager.swift
│   └── MockStorageManager.swift
└── Helpers/
    └── TestHelpers.swift
```

### UI Tests (`speaktypeUITests/`)

```
speaktypeUITests/
├── Screens/
│   ├── HomeScreenUITests.swift
│   └── SettingsScreenUITests.swift
├── Flows/
│   ├── OnboardingFlowTests.swift
│   └── UserFlowTests.swift
└── Helpers/
    └── UITestHelpers.swift
```

## Documentation Structure (`docs/`)

```
docs/
├── ARCHITECTURE.md              # Architecture overview
├── FOLDER_STRUCTURE.md          # This file
├── API.md                       # API documentation
├── SETUP.md                     # Setup instructions
└── images/                      # Documentation images
    └── architecture-diagram.png
```

## File Naming Conventions

### Swift Files

1. **Views**: Use descriptive names ending with `View`
   - `HomeView.swift`
   - `SettingsView.swift`
   - `UserProfileView.swift`

2. **ViewModels**: Match view name + `ViewModel`
   - `HomeViewModel.swift`
   - `SettingsViewModel.swift`
   - `UserProfileViewModel.swift`

3. **Models**: Use singular nouns
   - `User.swift`
   - `Settings.swift`
   - `Article.swift`

4. **Services**: Descriptive name + `Manager` or `Service`
   - `NetworkManager.swift`
   - `AuthenticationService.swift`
   - `StorageManager.swift`

5. **Extensions**: Type name + `+Extensions`
   - `View+Extensions.swift`
   - `Color+Extensions.swift`
   - `String+Extensions.swift`

6. **Protocols**: Descriptive name + `Protocol` or `-able` suffix
   - `NetworkServiceProtocol.swift`
   - `Cacheable.swift`
   - `Validatable.swift`

### Test Files

Test files should mirror the structure of the main app with `Tests` suffix:
- `HomeViewModel.swift` → `HomeViewModelTests.swift`
- `User.swift` → `UserTests.swift`

## Organization Guidelines

### 1. Group Related Files

Use Xcode groups (folders) to organize related files:
- Group views by feature or screen
- Group models by domain
- Group services by functionality

### 2. Keep Files Focused

- One primary type per file
- Related extensions can be in the same file
- Keep files under 400 lines when possible

### 3. Use MARK Comments

Organize code within files using `// MARK:` comments:

```swift
// MARK: - Properties
private let service: DataService
@Published var items: [Item] = []

// MARK: - Initialization
init(service: DataService = DataService()) {
    self.service = service
}

// MARK: - Public Methods
func loadData() {
    // ...
}

// MARK: - Private Methods
private func processData() {
    // ...
}
```

### 4. Alphabetical Ordering

Within groups, order files alphabetically for easy navigation.

### 5. Shared Components

Place reusable components in appropriate shared folders:
- `Views/Components/` for UI components
- `Utilities/Extensions/` for extensions
- `Utilities/Helpers/` for helper functions

## Asset Organization

### Assets.xcassets Structure

```
Assets.xcassets/
├── AppIcon.appiconset/
├── AccentColor.colorset/
├── Colors/
│   ├── PrimaryColor.colorset/
│   ├── SecondaryColor.colorset/
│   └── BackgroundColor.colorset/
├── Images/
│   ├── Icons/
│   │   ├── HomeIcon.imageset/
│   │   └── SettingsIcon.imageset/
│   └── Illustrations/
│       └── EmptyState.imageset/
└── Symbols/
    └── CustomSymbol.symbolset/
```

### Asset Naming

- Use descriptive, lowercase names with hyphens
- Group related assets with prefixes
- Examples:
  - `icon-home`
  - `button-primary-background`
  - `illustration-empty-state`

## Configuration Files

### Root Level Configuration

- `.gitignore` - Git ignore patterns
- `.swiftlint.yml` - SwiftLint rules
- `README.md` - Project overview
- `CONTRIBUTING.md` - Contribution guidelines

### Xcode Configuration

- `Info.plist` - App metadata and configuration
- `*.entitlements` - App capabilities and permissions
- `*.xcconfig` - Build configuration (optional)

## Best Practices

### 1. Consistent Structure

Maintain consistent folder structure across features:
```
Feature/
├── FeatureView.swift
├── FeatureViewModel.swift
├── FeatureModel.swift
└── Components/
    └── FeatureComponent.swift
```

### 2. Avoid Deep Nesting

Keep folder hierarchy shallow (max 3-4 levels deep).

### 3. Clear Boundaries

Maintain clear separation between:
- UI (Views)
- Logic (ViewModels)
- Data (Models)
- Services

### 4. Scalability

Structure should scale as the app grows:
- Easy to add new features
- Easy to find existing code
- Easy to refactor

### 5. Team Collaboration

- Clear structure helps team members find code
- Consistent naming reduces confusion
- Documented conventions prevent debates

## Adding New Features

When adding a new feature, follow this checklist:

1. **Create folder structure**:
   ```
   Views/Screens/NewFeature/
   ViewModels/
   Models/
   ```

2. **Add necessary files**:
   - View file(s)
   - ViewModel
   - Model (if needed)
   - Service (if needed)

3. **Add tests**:
   - Unit tests for ViewModel
   - UI tests for critical flows

4. **Update documentation**:
   - Update README if needed
   - Add API documentation
   - Update architecture docs

## Migration Guide

If you're reorganizing existing code:

1. **Plan the structure** first
2. **Move files** in Xcode (not Finder) to maintain references
3. **Update imports** if needed
4. **Run tests** to ensure nothing broke
5. **Update documentation**
6. **Commit changes** with clear message

## Questions?

If you're unsure where to place a file:
1. Check existing similar files
2. Refer to this document
3. Ask the team
4. Document your decision

Remember: Consistency is more important than perfection!

