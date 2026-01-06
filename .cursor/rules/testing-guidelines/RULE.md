---
description: "Testing guidelines for unit tests, UI tests, and test organization"
alwaysApply: false
---

# Testing Guidelines

## Test Organization

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

## Unit Tests

### What to Test
- Test ViewModels with mocked services
- Test business logic in Models
- Test Services with mocked dependencies
- Aim for 80%+ code coverage

### Test Naming
Use descriptive names: `test_WhatIsBeingTested_Scenario_ExpectedResult`

Examples:
```swift
func test_loadData_withValidResponse_updatesDataProperty()
func test_login_withInvalidCredentials_setsErrorMessage()
func test_updateProfile_withNetworkError_keepsOriginalData()
```

### Test Structure
Follow Arrange-Act-Assert pattern:

```swift
func test_loadData_withValidResponse_updatesDataProperty() {
    // Arrange
    let mockService = MockDataService()
    let viewModel = MyViewModel(service: mockService)
    let expectedData = [Item(id: 1, name: "Test")]
    mockService.dataToReturn = expectedData
    
    // Act
    viewModel.loadData()
    
    // Assert
    XCTAssertEqual(viewModel.data, expectedData)
    XCTAssertFalse(viewModel.isLoading)
    XCTAssertNil(viewModel.errorMessage)
}
```

### Mocking Dependencies
Create mock services for testing:

```swift
class MockUserService: UserServiceProtocol {
    var userToReturn: User?
    var errorToThrow: Error?
    
    func fetchUser(id: UUID) async throws -> User {
        if let error = errorToThrow {
            throw error
        }
        return userToReturn ?? User(id: id, name: "Test", email: "test@example.com")
    }
}
```

## UI Tests

### What to Test
- Test critical user flows
- Test navigation paths
- Test error states
- Keep tests independent

### UI Test Example
```swift
func testUserCanLogin() throws {
    let app = XCUIApplication()
    app.launch()
    
    // Navigate to login
    app.buttons["Login"].tap()
    
    // Enter credentials
    app.textFields["Email"].tap()
    app.textFields["Email"].typeText("test@example.com")
    app.secureTextFields["Password"].tap()
    app.secureTextFields["Password"].typeText("password123")
    
    // Submit
    app.buttons["Sign In"].tap()
    
    // Verify success
    XCTAssertTrue(app.staticTexts["Welcome"].exists)
}
```

### UI Test Best Practices
- Use accessibility identifiers for UI elements
- Keep tests independent and isolated
- Test both success and error scenarios
- Clean up state between tests

## Running Tests

### Command Line
```bash
# Run all tests
make test

# Run unit tests only
make test-unit

# Run UI tests only
make test-ui

# Run specific test
xcodebuild test -scheme speaktype -only-testing:speaktypeTests/MyViewModelTests
```

### Xcode
- Run all tests: `⌘U`
- Run single test: Click diamond icon next to test
- Run test class: Click diamond icon next to class

## Code Coverage

### Enable Coverage
1. Edit Scheme > Test
2. Check "Gather coverage data"
3. Run tests

### View Coverage
- Product > Show Code Coverage (⌘9 → Coverage tab)
- Aim for 80%+ coverage
- Focus on critical paths

## Testing Checklist

### Before Submitting
- [ ] All tests pass
- [ ] New features have tests
- [ ] Tests are independent
- [ ] Tests follow naming conventions
- [ ] Mocks are used for external dependencies
- [ ] Code coverage meets target

## Best Practices

### Do
- Test behavior, not implementation
- Keep tests simple and focused
- Use descriptive test names
- Mock external dependencies
- Test edge cases and error conditions

### Don't
- Test private methods directly
- Create tests that depend on each other
- Use hardcoded delays (use expectations)
- Test framework code
- Skip writing tests for bug fixes

## Resources

- [XCTest Documentation](https://developer.apple.com/documentation/xctest)
- [Testing Swift Code](https://developer.apple.com/documentation/xcode/testing-your-apps-in-xcode)

