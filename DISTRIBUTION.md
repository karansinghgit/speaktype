# 📦 Distribution Quick Start

## TL;DR - Create a Release in 3 Steps

```bash
# 1. Run the interactive release script
./scripts/create-release.sh

# 2. Wait ~5 minutes for GitHub Actions

# 3. Share the release link! 🎉
```

---

## What You Get

Your repository now has:

### ✅ Automated GitHub Actions Release
- `.github/workflows/release.yml` - Builds and publishes releases automatically
- Triggers when you push a tag like `v1.0.0`
- Creates DMG and ZIP files
- Publishes to GitHub Releases

### ✅ Makefile Commands
```bash
make release    # Build both ZIP and DMG locally
make package    # Build ZIP only
make dmg        # Build DMG only
make help       # See all commands
```

### ✅ Interactive Release Script
- `./scripts/create-release.sh` - Guides you through the entire release process
- Validates version format
- Builds artifacts
- Creates git tags
- Pushes to GitHub

### ✅ Documentation
- `RELEASING.md` - Detailed release documentation
- Updated README with download instructions
- This file - Quick reference

---

## Two Ways to Release

### Option 1: Automated (Recommended)

```bash
# Use the interactive script
./scripts/create-release.sh
```

**What it does:**
1. Asks for new version number (e.g., `v1.0.0`)
2. Validates format and checks for conflicts
3. Commits any pending changes (optional)
4. Builds release artifacts locally
5. Creates git tag
6. Pushes to GitHub
7. GitHub Actions creates the release automatically

### Option 2: Manual

```bash
# 1. Build release artifacts
make release

# 2. Create and push tag
git tag v1.0.0
git push origin main
git push origin v1.0.0

# 3. GitHub Actions takes over
```

---

## First Release Checklist

Before your first release:

- [ ] Update README with your GitHub username
  - Replace `yourusername` in download links
  - Update any placeholder emails

- [ ] Update version in Xcode
  - Open project → Target → General → Version

- [ ] Test local build
  ```bash
  make clean
  make release
  # Check dist/ folder
  ```

- [ ] Commit everything
  ```bash
  git add .
  git commit -m "Prepare for first release"
  git push origin main
  ```

- [ ] Create first release
  ```bash
  ./scripts/create-release.sh
  # Enter: v1.0.0
  ```

---

## After Release

### View Your Release

```
https://github.com/YOUR_USERNAME/speaktype/releases
```

### Update README Download Link

The download link in your README is:
```markdown
[Download Latest Release](https://github.com/yourusername/speaktype/releases/latest)
```

Update `yourusername` to your actual GitHub username.

### Share Your Release

Once published, share on:
- Reddit (r/macapps, r/swift)
- Hacker News (Show HN)
- Twitter/X
- Product Hunt

**Template:**
```
🎉 SpeakType v1.0.0 - Fast offline voice-to-text for macOS

✨ Features:
- 100% offline transcription
- Works anywhere on your Mac
- Powered by Whisper AI
- Free & open source

📥 Download: https://github.com/YOUR_USERNAME/speaktype/releases/latest
```

---

## Testing the Release

After GitHub Actions completes:

1. **Download the DMG** from the release page
2. **Open it** and drag to Applications
3. **Right-click → Open** (first time)
4. **Test all features:**
   - Permissions prompt
   - Model download
   - Hotkey recording
   - Transcription

---

## Troubleshooting

### "Command not found: ./scripts/create-release.sh"

```bash
chmod +x ./scripts/create-release.sh
./scripts/create-release.sh
```

### "create-dmg not found"

For better DMG creation:
```bash
brew install create-dmg
```

Or the Makefile will fall back to `hdiutil` (works fine).

### GitHub Actions Fails

1. Go to Actions tab in GitHub
2. Click the failed workflow
3. Check logs for errors
4. Common issues:
   - Xcode version (we use 15.2)
   - Build errors (fix locally first)

### Users Can't Open the App

This is expected! The app isn't code-signed yet.

**Users must:**
1. Right-click the app
2. Select "Open"
3. Click "Open" in the dialog

This is documented in the release notes.

### Want to Remove a Release?

```bash
# Delete remote tag
git push origin :refs/tags/v1.0.0

# Delete local tag
git tag -d v1.0.0

# Delete release on GitHub (manually in UI)
```

---

## Code Signing (Future)

To remove the "unidentified developer" warning:

1. **Get Apple Developer Account** ($99/year)
2. **Create Developer ID Certificate**
3. **Sign the app:**
   ```bash
   codesign --deep --force --verify \
     --sign "Developer ID Application: Your Name (ID)" \
     --options runtime \
     build/Release/speaktype.app
   ```
4. **Notarize with Apple:**
   ```bash
   xcrun notarytool submit speaktype.zip \
     --apple-id "your@email.com" \
     --password "app-specific-password" \
     --team-id "TEAM_ID" \
     --wait
   ```
5. **Update GitHub Actions** to sign automatically

See `RELEASING.md` for detailed instructions.

---

## Questions?

- 📚 **Detailed docs:** See `RELEASING.md`
- 🐛 **Issues:** Open a GitHub issue
- 💬 **Help:** GitHub Discussions

---

## Quick Commands Reference

```bash
# Build
make build          # Debug build
make build-release  # Release build
make clean          # Clean artifacts

# Release
make release        # Build ZIP + DMG
make package        # Build ZIP only
make dmg            # Build DMG only

# Test
make test           # Run all tests
make test-unit      # Unit tests only

# Development
make run            # Run the app
make xcode          # Open in Xcode
make help           # See all commands

# Release Script
./scripts/create-release.sh    # Interactive release
```

---

**🎉 You're all set! Ready to release your app to the world!**
