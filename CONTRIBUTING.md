# Contributing to SpeakType

Thank you for your interest in contributing to SpeakType! This document provides guidelines and instructions for contributing.

## Getting Started

1. Fork the repository
2. Clone your fork locally
3. Create a new branch for your feature or bugfix
4. Make your changes
5. Test your changes thoroughly
6. Submit a pull request

## Development Setup

1. Ensure you have Xcode 15.0+ installed
2. Open `speaktype.xcodeproj` in Xcode
3. Build the project (⌘B) to ensure everything compiles
4. Run tests (⌘U) to verify all tests pass

## Code Style Guidelines

### Swift Style

- Follow the [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use 4 spaces for indentation (not tabs)
- Maximum line length: 120 characters
- Use meaningful names for variables, functions, and types
- Prefer `let` over `var` when possible
- Use type inference where appropriate

### Naming Conventions

- **Types**: Use UpperCamelCase (e.g., `UserProfile`, `NetworkManager`)
- **Functions/Variables**: Use lowerCamelCase (e.g., `fetchUserData`, `isLoggedIn`)
- **Constants**: Use lowerCamelCase (e.g., `maxRetryCount`)
- **Enums**: Use UpperCamelCase for the enum and lowerCamelCase for cases

### Code Organization

- Group related functionality together
- Use `// MARK: -` comments to organize code sections
- Keep files focused on a single responsibility
- Limit file length to ~400 lines when possible

### SwiftUI Best Practices

- Break down complex views into smaller, reusable components
- Use `@State` for view-local state
- Use `@StateObject` for view-owned observable objects
- Use `@ObservedObject` for passed-in observable objects
- Use `@EnvironmentObject` for app-wide shared state
- Prefer composition over inheritance

## Folder Structure

When adding new files, follow this structure:

```
speaktype/
├── App/
│   ├── speaktypeApp.swift      # App entry point
│   └── AppDelegate.swift        # App delegate (if needed)
├── Views/
│   ├── ContentView.swift        # Main views
│   ├── Components/              # Reusable UI components
│   └── Screens/                 # Full screen views
├── ViewModels/
│   └── *ViewModel.swift         # View models
├── Models/
│   └── *.swift                  # Data models
├── Services/
│   ├── Network/                 # Networking layer
│   ├── Storage/                 # Data persistence
│   └── *.swift                  # Other services
├── Utilities/
│   ├── Extensions/              # Swift extensions
│   ├── Helpers/                 # Helper functions
│   └── Constants.swift          # App constants
└── Resources/
    └── Assets.xcassets/         # Images, colors, etc.
```

## Commit Messages

Write clear, concise commit messages:

- Use the imperative mood ("Add feature" not "Added feature")
- First line should be 50 characters or less
- Add a blank line before the body (if needed)
- Explain *what* and *why*, not *how*

Example:
```
Add user authentication flow

- Implement login screen with email/password
- Add token storage in Keychain
- Create authentication service
```

## Pull Request Process

1. **Update Documentation**: Update README.md if you change functionality
2. **Add Tests**: Include unit tests for new features
3. **Run Tests**: Ensure all tests pass before submitting
4. **Check Code Style**: Follow the style guidelines above
5. **Describe Changes**: Write a clear PR description explaining:
   - What changes were made
   - Why they were made
   - How to test them

### PR Title Format

- `feat: Add new feature`
- `fix: Fix bug in component`
- `docs: Update documentation`
- `refactor: Refactor code structure`
- `test: Add tests for feature`
- `chore: Update dependencies`

## Testing Guidelines

### Unit Tests

- Test business logic and view models
- Use descriptive test names: `testUserLoginWithValidCredentials()`
- Follow the Arrange-Act-Assert pattern
- Mock external dependencies
- Aim for 80%+ code coverage

### UI Tests

- Test critical user flows
- Use accessibility identifiers for UI elements
- Keep tests independent and isolated
- Test both success and error scenarios

## Code Review

All submissions require code review. We use GitHub pull requests for this purpose:

- Be respectful and constructive
- Explain reasoning behind suggestions
- Be open to feedback
- Respond to comments promptly

## Questions?

If you have questions about contributing, please open an issue or reach out to the maintainers.

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.

