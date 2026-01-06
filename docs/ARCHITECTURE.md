# Architecture

## Overview

SpeakType follows the MVVM (Model-View-ViewModel) architecture pattern, which provides clear separation of concerns and makes the codebase maintainable and testable.

## Architecture Layers

### 1. Models (`Models/`)

Models represent the data structures and business entities in the application.

**Responsibilities:**
- Define data structures
- Implement Codable for serialization
- Business logic related to data validation
- Computed properties for derived data

**Example:**
```swift
struct User: Codable, Identifiable {
    let id: UUID
    var name: String
    var email: String
    
    var displayName: String {
        name.isEmpty ? email : name
    }
}
```

### 2. Views (`Views/`)

Views are SwiftUI components that display data and handle user interactions.

**Responsibilities:**
- Display UI elements
- Handle user input
- Observe ViewModel state
- Navigate between screens

**Structure:**
- `Views/Screens/` - Full screen views
- `Views/Components/` - Reusable UI components

**Example:**
```swift
struct UserProfileView: View {
    @StateObject private var viewModel = UserProfileViewModel()
    
    var body: some View {
        VStack {
            Text(viewModel.user.displayName)
            Button("Update") {
                viewModel.updateProfile()
            }
        }
    }
}
```

### 3. ViewModels (`ViewModels/`)

ViewModels manage view state and handle business logic.

**Responsibilities:**
- Manage view state
- Handle user actions
- Coordinate with Services
- Transform data for display
- Handle validation

**Guidelines:**
- Conform to `ObservableObject`
- Use `@Published` for state that views observe
- Keep UI-independent (no SwiftUI imports except for simple types)
- Use dependency injection for services

**Example:**
```swift
class UserProfileViewModel: ObservableObject {
    @Published var user: User
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let userService: UserServiceProtocol
    
    init(userService: UserServiceProtocol = UserService()) {
        self.userService = userService
    }
    
    func updateProfile() {
        isLoading = true
        Task {
            do {
                user = try await userService.updateUser(user)
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}
```

### 4. Services (`Services/`)

Services handle business logic, data persistence, and external communication.

**Responsibilities:**
- Network requests
- Data persistence
- Business logic
- External API integration

**Structure:**
- `Services/Network/` - Networking layer
- `Services/Storage/` - Data persistence (UserDefaults, CoreData, etc.)

**Guidelines:**
- Define protocols for testability
- Use async/await for asynchronous operations
- Handle errors appropriately
- Keep services focused on a single responsibility

**Example:**
```swift
protocol UserServiceProtocol {
    func fetchUser(id: UUID) async throws -> User
    func updateUser(_ user: User) async throws -> User
}

class UserService: UserServiceProtocol {
    private let networkManager: NetworkManager
    
    init(networkManager: NetworkManager = .shared) {
        self.networkManager = networkManager
    }
    
    func fetchUser(id: UUID) async throws -> User {
        try await networkManager.request(endpoint: .user(id))
    }
    
    func updateUser(_ user: User) async throws -> User {
        try await networkManager.request(endpoint: .updateUser(user))
    }
}
```

### 5. Utilities (`Utilities/`)

Helper functions, extensions, and constants.

**Structure:**
- `Utilities/Extensions/` - Swift and SwiftUI extensions
- `Utilities/Helpers/` - Helper functions and utilities
- `Utilities/Constants.swift` - App-wide constants

## Data Flow

1. **User Interaction** → View receives user input
2. **View → ViewModel** → View calls ViewModel method
3. **ViewModel → Service** → ViewModel requests data from Service
4. **Service → External** → Service fetches/saves data
5. **Service → ViewModel** → Service returns data to ViewModel
6. **ViewModel → View** → ViewModel updates @Published properties
7. **View Update** → SwiftUI automatically re-renders view

## Dependency Injection

Use protocol-based dependency injection for better testability:

```swift
// Define protocol
protocol DataServiceProtocol {
    func fetchData() async throws -> [Item]
}

// Implement service
class DataService: DataServiceProtocol {
    func fetchData() async throws -> [Item] {
        // Implementation
    }
}

// Inject in ViewModel
class MyViewModel: ObservableObject {
    private let dataService: DataServiceProtocol
    
    init(dataService: DataServiceProtocol = DataService()) {
        self.dataService = dataService
    }
}

// Easy to mock for testing
class MockDataService: DataServiceProtocol {
    func fetchData() async throws -> [Item] {
        return [Item(id: 1, name: "Test")]
    }
}
```

## State Management

### Local State
Use `@State` for view-local state:
```swift
@State private var isExpanded = false
```

### Shared State
Use `@StateObject` for view-owned objects:
```swift
@StateObject private var viewModel = MyViewModel()
```

Use `@ObservedObject` for passed-in objects:
```swift
@ObservedObject var viewModel: MyViewModel
```

### App-Wide State
Use `@EnvironmentObject` for app-wide shared state:
```swift
@EnvironmentObject var appState: AppState
```

## Error Handling

1. **Service Layer**: Throw specific errors
2. **ViewModel Layer**: Catch and transform errors for display
3. **View Layer**: Display errors to user

```swift
// Custom errors
enum NetworkError: LocalizedError {
    case invalidURL
    case noData
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .noData: return "No data received"
        case .decodingError: return "Failed to decode data"
        }
    }
}

// ViewModel handles errors
@Published var errorMessage: String?

func loadData() {
    Task {
        do {
            data = try await service.fetchData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

## Testing Strategy

### Unit Tests
- Test ViewModels with mocked services
- Test Models for validation logic
- Test Services with mocked network layer

### UI Tests
- Test critical user flows
- Test navigation
- Test error states

### Integration Tests
- Test ViewModel + Service integration
- Test data persistence

## Best Practices

1. **Single Responsibility**: Each component should have one clear purpose
2. **Dependency Injection**: Use protocols for testability
3. **Async/Await**: Use modern concurrency for asynchronous operations
4. **Error Handling**: Handle errors at appropriate layers
5. **Immutability**: Prefer `let` over `var` when possible
6. **Type Safety**: Use Swift's type system to prevent errors
7. **Documentation**: Document complex logic and public APIs
8. **Testing**: Write tests for business logic and critical flows

## Resources

- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)

