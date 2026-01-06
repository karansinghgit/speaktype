---
description: "Swift coding standards and style guidelines for SpeakType macOS app"
alwaysApply: true
---

# Swift Style Guide

## Code Style

### Formatting
- Use 4 spaces for indentation (no tabs)
- Maximum line length: 120 characters
- Use type inference where appropriate
- Prefer `let` over `var` when possible

### Naming Conventions
- **Types**: UpperCamelCase (e.g., `UserProfile`, `NetworkManager`)
- **Functions/Variables**: lowerCamelCase (e.g., `fetchUserData`, `isLoggedIn`)
- **Constants**: lowerCamelCase (e.g., `maxRetryCount`)
- **Enums**: UpperCamelCase for enum, lowerCamelCase for cases
- **Files**: Match primary type name (e.g., `UserProfile.swift`)
- **ViewModels**: ViewName + "ViewModel" (e.g., `HomeViewModel.swift`)
- **Extensions**: TypeName + "+Extensions" (e.g., `View+Extensions.swift`)

### Code Organization

Use `// MARK: -` to organize code sections in this order:
1. Properties
2. Initialization
3. Public Methods
4. Private Methods

Example:
```swift
class MyViewModel: ObservableObject {
    // MARK: - Properties
    @Published var data: [Item] = []
    private let service: DataService
    
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
}
```

### File Guidelines
- One primary type per file
- Related extensions can be in the same file
- Keep files under 400 lines when possible
- Group related functionality together

### Async/Await

Use modern Swift concurrency:

```swift
func loadData() {
    Task {
        do {
            let result = try await service.fetchData()
            await MainActor.run {
                self.data = result
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
```

### Error Handling

Create custom error types conforming to `LocalizedError`:

```swift
enum NetworkError: LocalizedError {
    case invalidURL
    case noData
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .noData: return "No data received"
        }
    }
}
```

## Code Quality

### Before Submitting
- [ ] Code follows Swift style guidelines
- [ ] SwiftLint shows no warnings/errors
- [ ] No commented-out code
- [ ] No debug print statements
- [ ] Proper error handling
- [ ] Meaningful variable and function names

