---
description: "SwiftUI best practices for building views, managing state, and creating reusable components"
alwaysApply: true
---

# SwiftUI Best Practices

## View Guidelines

### Component Design
- Break down complex views into smaller, reusable components
- Keep views focused and under 200 lines
- Prefer composition over inheritance
- Extract repeated UI patterns into components

### File Organization
- Place full-screen views in `Views/Screens/`
- Place reusable components in `Views/Components/`
- Include SwiftUI Preview for all views

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

## Common Patterns

### Loading States
```swift
@Published var isLoading = false
@Published var errorMessage: String?

func loadData() {
    isLoading = true
    errorMessage = nil
    
    Task {
        do {
            data = try await service.fetchData()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
```

### Navigation
Use NavigationStack for programmatic navigation:
```swift
@State private var path = NavigationPath()

NavigationStack(path: $path) {
    // Content
}
```

### Alerts and Sheets
```swift
@State private var showingAlert = false
@State private var showingSheet = false

.alert("Title", isPresented: $showingAlert) {
    Button("OK", role: .cancel) { }
}
.sheet(isPresented: $showingSheet) {
    DetailView()
}
```

## Performance Considerations

- Use `@State` only for view-local state
- Avoid expensive computations in view body
- Use `.task` for async work tied to view lifecycle
- Profile with Instruments for performance issues
- Lazy load data when appropriate

## Accessibility

- Add accessibility labels to interactive elements
- Support Dynamic Type
- Test with VoiceOver
- Ensure sufficient color contrast
- Support keyboard navigation

## File Creation

### New View
1. Create in `Views/Screens/` or `Views/Components/`
2. Name: `FeatureName + View.swift` (e.g., `HomeView.swift`)
3. Include: SwiftUI Preview

### New Component
1. Create in `Views/Components/`
2. Group related components in subfolders (e.g., `Components/Buttons/`)
3. Make components reusable and configurable

Example reusable component:
```swift
struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
    }
}
```

## View Extensions

Use extensions for common view modifiers:
```swift
extension View {
    func standardCornerRadius() -> some View {
        self.cornerRadius(Constants.UI.cornerRadius)
    }
    
    func standardPadding() -> some View {
        self.padding(Constants.UI.padding)
    }
}
```

## Resources

- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- [View+Extensions.swift](../../speaktype/Utilities/Extensions/View+Extensions.swift)
- [Color+Extensions.swift](../../speaktype/Utilities/Extensions/Color+Extensions.swift)

