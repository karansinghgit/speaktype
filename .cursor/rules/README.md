# Cursor Rules

This directory contains modular Cursor rules for the SpeakType project. Each rule is organized in its own folder with a `RULE.md` file.

## Available Rules

### Always Applied Rules

These rules are automatically applied to every chat session:

1. **swift-style-guide** - Swift coding standards and style guidelines
   - Code formatting and organization
   - Naming conventions
   - File structure guidelines

2. **mvvm-architecture** - MVVM architecture pattern guidelines
   - Folder structure and organization
   - Layer responsibilities (Models, Views, ViewModels, Services)
   - Dependency injection patterns

3. **swiftui-best-practices** - SwiftUI-specific best practices
   - View composition and state management
   - Common UI patterns
   - Performance considerations

4. **git-workflow** - Git commit and versioning standards
   - Conventional commit format
   - Semantic versioning
   - Branch strategy

### Intelligent Rules

These rules are applied when Cursor Agent determines they're relevant:

5. **testing-guidelines** - Testing standards and organization
   - Unit test structure
   - UI test best practices
   - Mocking patterns

## Rule Structure

Each rule follows this structure:

```
rule-name/
└── RULE.md           # Main rule file with frontmatter
```

## Using Rules

### Automatic Application
Rules with `alwaysApply: true` are automatically included in every chat session.

### Manual Application
Reference a specific rule in chat using `@rule-name`:
```
@testing-guidelines How should I test this ViewModel?
```

### Agent-Based Application
Rules with `alwaysApply: false` are automatically included when the Agent determines they're relevant based on the description.

## Creating New Rules

1. Create a new folder in `.cursor/rules/`
2. Add a `RULE.md` file with frontmatter:

```markdown
---
description: "Brief description of what this rule covers"
alwaysApply: false
---

# Rule Content

Your rule content here...
```

3. Keep rules:
   - Under 500 lines
   - Focused on a single concern
   - Actionable and specific
   - Well-documented with examples

## Best Practices

- **Focused**: Each rule should cover a specific area
- **Composable**: Rules should work together without conflicts
- **Concrete**: Provide examples and code snippets
- **Maintained**: Update rules as project standards evolve

## Resources

- [Cursor Rules Documentation](https://docs.cursor.com/context/rules)
- [Project Documentation](../../docs/)
- [Contributing Guidelines](../../CONTRIBUTING.md)

