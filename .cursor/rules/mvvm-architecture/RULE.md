---
description: "MVVM architecture pattern guidelines for organizing code in Models, Views, ViewModels, and Services"
alwaysApply: true
---

# MVVM Architecture Pattern

## Folder Structure

```
speaktype/
├── App/                    # App entry point
├── Views/
│   ├── Screens/           # Full-screen views
│   └── Components/        # Reusable UI components
├── ViewModels/            # View models
├── Models/                # Data models
├── Services/
│   ├── Network/          # Networking layer
│   └── Storage/          # Data persistence
├── Utilities/
│   ├── Extensions/       # Swift extensions
│   ├── Helpers/          # Helper functions
│   └── Constants.swift   # App constants
└── Resources/            # Assets, localizations
```

## Layer Responsibilities

### Models (`Models/`)
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

### Views (`Views/`)
- Display UI elements
- Handle user input
- Observe ViewModel state
- Navigate between screens

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

### ViewModels (`ViewModels/`)
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

### Services (`Services/`)
- Network requests
- Data persistence
- Business logic
- External API integration

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

## Dependency Injection

Always use protocol-based dependency injection for testability:

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

## Adding New Features

1. **Plan the structure**:
   - Identify required Models
   - Design View hierarchy
   - Create ViewModel for business logic
   - Determine Service needs

2. **Create files in order**:
   - Models first (data structures)
   - Services (business logic)
   - ViewModels (state management)
   - Views (UI components)

3. **Follow the folder structure**:
   - Place files in appropriate directories
   - Use consistent naming
   - Add to Xcode project properly

