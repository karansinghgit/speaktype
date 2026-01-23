# 🚀 Release Guide for SpeakType

This guide explains how to create and publish new releases of SpeakType.

## Quick Release

The easiest way to create a release:

```bash
./scripts/create-release.sh
```

This interactive script will:
- ✅ Check your current version
- ✅ Validate the new version format
- ✅ Build release artifacts
- ✅ Create a git tag
- ✅ Push to GitHub (triggers automated release)

---

## Manual Release Process

### Prerequisites

1. **Clean working directory**
   ```bash
   git status  # Should be clean
   ```

2. **On main/master branch**
   ```bash
   git checkout main
   git pull origin main
   ```

3. **Build tools installed**
   ```bash
   xcodebuild -version
   # Optional: brew install create-dmg  # For better DMG creation
   ```

### Step-by-Step Release

#### 1. Update Version Number

Update the version in Xcode:
1. Open `speaktype.xcodeproj`
2. Select the project in the navigator
3. Select the "speaktype" target
4. Go to "General" tab
5. Update **Version** (e.g., `1.0.0`)
6. Update **Build** if needed (e.g., `1`)

Or use `agvtool` (if configured):
```bash
agvtool new-marketing-version 1.0.0
```

#### 2. Update Changelog (Optional but Recommended)

Create or update `CHANGELOG.md`:

```markdown
## [1.0.0] - 2026-01-23

### Added
- Initial release
- Offline voice-to-text transcription
- Multiple Whisper AI models
- Global hotkey support
- Native macOS UI

### Fixed
- Bug fixes and improvements
```

#### 3. Commit Changes

```bash
git add .
git commit -m "Bump version to 1.0.0"
```

#### 4. Build Release Artifacts

```bash
# Clean previous builds
make clean

# Build release (creates ZIP and DMG)
make release
```

This creates:
- `dist/SpeakType.zip` - For GitHub releases
- `dist/SpeakType.dmg` - For direct download

#### 5. Create Git Tag

```bash
# Create annotated tag
git tag -a v1.0.0 -m "Release v1.0.0"

# Verify tag
git tag -l
```

#### 6. Push to GitHub

```bash
# Push commits
git push origin main

# Push tag (triggers GitHub Actions)
git push origin v1.0.0
```

#### 7. Monitor GitHub Actions

1. Go to: `https://github.com/yourusername/speaktype/actions`
2. Watch the "Release Build" workflow
3. Takes ~5 minutes to complete

#### 8. Verify Release

1. Go to: `https://github.com/yourusername/speaktype/releases`
2. Verify the release was created
3. Check that DMG and ZIP files are attached
4. Test download and installation

---

## GitHub Actions Automated Release

When you push a tag starting with `v`, GitHub Actions automatically:

1. ✅ Builds the app in Release mode
2. ✅ Creates a DMG installer
3. ✅ Creates a ZIP package
4. ✅ Creates a GitHub release
5. ✅ Uploads both files
6. ✅ Generates release notes

### Workflow File

Located at: `.github/workflows/release.yml`

### Manual Trigger

You can also trigger manually:
1. Go to Actions → Release Build
2. Click "Run workflow"
3. Enter version (e.g., `v1.0.0`)
4. Click "Run workflow"

---

## Release Checklist

Before releasing, make sure:

- [ ] All tests pass (`make test`)
- [ ] Code is linted (`make lint`)
- [ ] Version number is updated
- [ ] CHANGELOG is updated (if you have one)
- [ ] README is up to date
- [ ] No uncommitted changes
- [ ] On main/master branch
- [ ] Built and tested locally (`make release`)
- [ ] Git tag follows format `vX.Y.Z`

---

## Versioning Strategy

SpeakType follows [Semantic Versioning](https://semver.org/):

- **Major (v2.0.0)**: Breaking changes, major new features
- **Minor (v1.1.0)**: New features, backwards compatible
- **Patch (v1.0.1)**: Bug fixes, minor improvements

### Examples

- `v1.0.0` - First stable release
- `v1.1.0` - Added streaming transcription
- `v1.1.1` - Fixed hotkey bug
- `v2.0.0` - Redesigned UI (breaking changes)

### Pre-release Versions

For testing:
- `v1.0.0-beta.1` - Beta release
- `v1.0.0-rc.1` - Release candidate
- `v1.0.0-alpha.1` - Alpha release

---

## Distribution Without Code Signing

Currently, SpeakType is distributed **without Apple code signing** (requires paid developer account).

### What Users See

Users will see: **"speaktype cannot be opened because it is from an unidentified developer"**

### User Instructions

Tell users to:
1. Download the DMG
2. Open the DMG
3. Drag app to Applications
4. **Right-click** → **Open** (not double-click)
5. Click **"Open"** in the dialog
6. App will open and be trusted going forward

This is included in the release notes automatically.

---

## Code Signing (Future)

To remove the security warning, you'll need:

1. **Apple Developer Account** ($99/year)
   - Sign up at: https://developer.apple.com/

2. **Developer ID Certificate**
   ```bash
   # Sign the app
   codesign --deep --force --verify --verbose \
     --sign "Developer ID Application: Your Name (TEAM_ID)" \
     --options runtime \
     build/Release/speaktype.app
   ```

3. **Notarize with Apple**
   ```bash
   # Create ZIP for notarization
   ditto -c -k --keepParent build/Release/speaktype.app speaktype.zip
   
   # Submit for notarization
   xcrun notarytool submit speaktype.zip \
     --apple-id "your@email.com" \
     --password "app-specific-password" \
     --team-id "TEAM_ID" \
     --wait
   
   # Staple notarization ticket
   xcrun stapler staple build/Release/speaktype.app
   ```

4. **Update GitHub Actions**
   - Add secrets: `APPLE_ID`, `APPLE_PASSWORD`, `TEAM_ID`, `CERTIFICATE_P12`, `CERTIFICATE_PASSWORD`
   - Update workflow to sign and notarize

---

## Troubleshooting

### Build Fails

```bash
# Clean everything
make clean
rm -rf ~/Library/Developer/Xcode/DerivedData/speaktype-*

# Try again
make release
```

### GitHub Actions Fails

Check the logs:
1. Go to Actions tab
2. Click the failed workflow
3. Check each step's logs
4. Common issues:
   - Xcode version mismatch
   - Missing dependencies
   - Build errors

### Tag Already Exists

```bash
# Delete local tag
git tag -d v1.0.0

# Delete remote tag (careful!)
git push origin :refs/tags/v1.0.0

# Create new tag
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

### Wrong Version Tagged

```bash
# Delete the tag
git tag -d v1.0.0
git push origin :refs/tags/v1.0.0

# Delete the release on GitHub (manually)

# Fix version, create new tag
git tag -a v1.0.1 -m "Release v1.0.1"
git push origin v1.0.1
```

---

## Testing Releases

Before announcing:

1. **Download from GitHub**
   ```bash
   # Test the DMG
   open SpeakType.dmg
   # Drag to Applications, test install
   ```

2. **Test on Clean Mac**
   - Ideally test on a Mac without Xcode
   - Test the security warning flow
   - Ensure app runs correctly

3. **Test First-Run Experience**
   - Permissions prompts work?
   - Model download works?
   - Hotkey works?

---

## Release Cadence

Recommended schedule:

- **Patch releases**: As needed for critical bugs
- **Minor releases**: Every 2-4 weeks
- **Major releases**: Every 3-6 months

---

## Announcement Template

After releasing, announce on:

- GitHub Discussions
- Twitter/X
- Reddit (r/macapps, r/swift)
- Hacker News (Show HN)

**Template:**

```markdown
🎉 SpeakType v1.0.0 Released!

Fast, offline voice-to-text for macOS. Press a hotkey, speak, and 
instantly paste text anywhere on your Mac.

✨ What's New:
- [Feature 1]
- [Feature 2]
- [Bug fixes]

📥 Download: https://github.com/yourusername/speaktype/releases/latest

🔒 100% offline, privacy-first, open source.

Feedback welcome!
```

---

## Questions?

- 🐛 Issues: https://github.com/yourusername/speaktype/issues
- 💬 Discussions: https://github.com/yourusername/speaktype/discussions
- 📧 Email: your.email@example.com
