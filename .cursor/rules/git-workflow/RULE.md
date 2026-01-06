---
description: "Git workflow guidelines including commit message format, branching strategy, and semantic versioning"
alwaysApply: true
---

# Git Workflow

## Commit Messages

Follow Conventional Commits format:

```
<type>(<scope>): <subject>
```

### Types
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, no logic change)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Build process, dependencies, tooling

### Examples
```
feat(auth): add user authentication flow
fix(home): resolve crash on data load
docs: update README with setup instructions
refactor(network): improve error handling
test(viewmodel): add unit tests for HomeViewModel
chore: update SwiftLint configuration
```

### Guidelines
- Use the imperative mood ("Add feature" not "Added feature")
- First line should be 50 characters or less
- Keep commits focused and atomic
- One logical change per commit

## Semantic Versioning

Follow [SemVer](https://semver.org/): `MAJOR.MINOR.PATCH`

- **MAJOR**: Breaking changes (e.g., 1.0.0 → 2.0.0)
- **MINOR**: New features, backward compatible (e.g., 1.0.0 → 1.1.0)
- **PATCH**: Bug fixes, backward compatible (e.g., 1.0.0 → 1.0.1)

### Version Examples
- `0.1.0` - Initial development
- `0.2.0` - Added new feature
- `0.2.1` - Bug fix
- `1.0.0` - First stable release
- `1.1.0` - Added feature to stable
- `2.0.0` - Breaking changes

## Branch Strategy

- `main`: Production-ready code
- `develop`: Development branch
- `feature/*`: New features (e.g., `feature/user-auth`)
- `fix/*`: Bug fixes (e.g., `fix/login-crash`)
- `hotfix/*`: Urgent production fixes

### Branch Naming
Use descriptive names with hyphens:
- `feature/user-authentication`
- `fix/home-screen-crash`
- `refactor/network-layer`

## Commit Frequency

- Commit after completing a logical unit of work
- Commit before switching contexts
- Commit at least daily
- Make atomic commits (one logical change per commit)

## Best Practices

### Before Committing
- [ ] Run tests to ensure they pass
- [ ] Check SwiftLint for warnings/errors
- [ ] Remove debug code and print statements
- [ ] Ensure code compiles
- [ ] Stage only related changes

### Commit Organization
- Separate formatting changes from logic changes
- Group related file changes together
- Don't mix refactoring with feature additions

### Commit Messages to Avoid
❌ "fix stuff"
❌ "WIP"
❌ "updates"
❌ "changes"

✅ "feat(auth): implement OAuth login flow"
✅ "fix(profile): resolve avatar upload issue"
✅ "refactor(network): extract response parsing"

## Git Commands

### Common Workflow
```bash
# Start new feature
git checkout -b feature/my-feature

# Stage changes
git add <files>

# Commit with message
git commit -m "feat(scope): description"

# Push to remote
git push origin feature/my-feature
```

### Useful Commands
```bash
# View status
git status

# View commit history
git log --oneline

# Amend last commit
git commit --amend

# Unstage files
git reset HEAD <file>
```

## Resources

- [Conventional Commits](https://www.conventionalcommits.org/)
- [Semantic Versioning](https://semver.org/)
- [Git Documentation](https://git-scm.com/doc)

