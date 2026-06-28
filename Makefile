# Makefile for SpeakType

.PHONY: help build clean clean-dev test lint format ci run run-dev run-release setup logs logs-live logs-errors logs-export install uninstall reinstall

# Default target
help:
	@echo "SpeakType - Available commands:"
	@echo ""
	@echo "Development:"
	@echo "  make setup         - Initial project setup"
	@echo "  make build         - Build the project (Debug)"
	@echo "  make run           - Run the application"
	@echo "  make run-dev       - Build and run SpeakType-Dev.app"
	@echo "  make clean         - Clean build artifacts"
	@echo "  make clean-dev     - 🧹 Clean ALL app data & permissions (fresh start)"
	@echo "  make xcode         - Open in Xcode"
	@echo "  make install       - Install SpeakType to /Applications"
	@echo "  make uninstall     - Fully uninstall (no rebuild)"
	@echo "  make reinstall     - Uninstall then install again"
	@echo ""
	@echo "Testing:"
	@echo "  make test          - Run all tests"
	@echo "  make test-unit     - Run unit tests only"
	@echo "  make test-ui       - Run UI tests only"
	@echo ""
	@echo "Distribution:"
	@echo "  make create-release - 🔨 Bump version, build, sign, notarize → dist/*.dmg"
	@echo "  make deploy-release - 🚀 Push tag + upload DMG to GitHub releases"
	@echo "  make run-release    - Run the last Release build locally"
	@echo "  make package        - Create ZIP package (unsigned)"
	@echo "  make dmg            - Create DMG installer (unsigned)"
	@echo ""
	@echo "Code Quality:"
	@echo "  make lint          - Run SwiftLint"
	@echo "  make format        - Format code with SwiftLint"
	@echo "  make ci            - Reproduce CI checks locally (build + unit tests + lint)"
	@echo ""
	@echo "Logging:"
	@echo "  make logs          - View live logs"
	@echo "  make logs-live     - Stream live logs (alias)"
	@echo "  make logs-errors   - View recent errors"
	@echo "  make logs-export   - Export last 24h logs to Desktop"
	@echo ""
	@echo "📚 For detailed release instructions, see: RELEASING.md"

# Create the local release (build + sign + notarize → dist/)
create-release:
	@./scripts/create-release.sh $(VERSION)

# Deploy the release to GitHub (push tag + upload DMG)
deploy-release:
	@./scripts/deploy-release.sh $(VERSION)

# Project setup
setup:
	@echo "Setting up project..."
	@which swiftlint > /dev/null || echo "⚠️  SwiftLint not installed. Install with: brew install swiftlint"
	@echo "✅ Setup complete!"

# Stamp BuildInfo.swift with the current compile timestamp
stamp-build-info:
	@TIMESTAMP=$$(date '+%b %d %H:%M:%S'); \
	echo "// Auto-generated — do not edit manually." > speaktype/Constants/BuildInfo.swift; \
	echo "let buildTimestamp = \"$$TIMESTAMP\"" >> speaktype/Constants/BuildInfo.swift

# Build the project
build: stamp-build-info
	@echo "Building SpeakType..."
	xcodebuild -scheme speaktype -configuration Debug build

# Build for release
build-release:
	@echo "Building SpeakType (Release)..."
	@xcodebuild -scheme speaktype -configuration Release build 2>&1 | grep -E "(error:|BUILD)" || true

# Run release build
run-release:
	@echo "Running SpeakType (Release)..."
	@open $$(find ~/Library/Developer/Xcode/DerivedData/speaktype-*/Build/Products/Release -name "speaktype.app" -type d | head -1)

# Run the application
run: stamp-build-info
	@echo "Running SpeakType..."
	@xcodebuild -scheme speaktype -configuration Debug build 2>&1 | grep -E "(error:|BUILD)" || true
	@open $$(find ~/Library/Developer/Xcode/DerivedData/speaktype-*/Build/Products/Debug -name "speaktype.app" -type d | head -1)

# Run the current checkout as a separate dev app identity
run-dev: stamp-build-info
	@./scripts/run-dev.sh

# Run all tests
test:
	@echo "Running tests..."
	xcodebuild test -scheme speaktype -destination 'platform=macOS'

# Run unit tests only
test-unit:
	@echo "Running unit tests..."
	xcodebuild test -scheme speaktype -destination 'platform=macOS' -only-testing:speaktypeTests

# Run UI tests only
test-ui:
	@echo "Running UI tests..."
	xcodebuild test -scheme speaktype -destination 'platform=macOS' -only-testing:speaktypeUITests

# Run SwiftLint
lint:
	@echo "Running SwiftLint..."
	@which swiftlint > /dev/null && swiftlint || echo "⚠️  SwiftLint not installed"

# Reproduce the GitHub Actions CI checks locally (build + unit tests + lint)
ci:
	@echo "Running CI checks locally..."
	xcodebuild -scheme speaktype -configuration Debug build CODE_SIGNING_ALLOWED=NO
	xcodebuild test -scheme speaktype -destination 'platform=macOS' -only-testing:speaktypeTests CODE_SIGNING_ALLOWED=NO
	@echo "--- SwiftLint (advisory) ---"
	@which swiftlint > /dev/null && swiftlint || echo "⚠️  SwiftLint not installed"

# Auto-fix SwiftLint issues
format:
	@echo "Formatting code with SwiftLint..."
	@which swiftlint > /dev/null && swiftlint --fix || echo "⚠️  SwiftLint not installed"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	xcodebuild clean -scheme speaktype
	rm -rf build/
	rm -rf DerivedData/

# Clean all app data and permissions (for fresh development testing)
clean-dev:
	@echo "🧹 Running development cleanup..."
	@./scripts/clean-dev.sh

# Archive the application
archive:
	@echo "Archiving SpeakType..."
	xcodebuild archive -scheme speaktype -archivePath build/speaktype.xcarchive

# Package for distribution (ZIP)
package:
	@echo "📦 Packaging SpeakType for distribution..."
	@make build-release
	@mkdir -p dist
	@cd build/Release && zip -r ../../dist/SpeakType.zip speaktype.app
	@echo "✅ Created dist/SpeakType.zip"
	@ls -lh dist/SpeakType.zip

# Create DMG (requires create-dmg: brew install create-dmg)
dmg:
	@echo "💿 Creating DMG installer..."
	@make build-release
	@mkdir -p dist
	@rm -f dist/SpeakType.dmg
	@# Find the app
	@APP_PATH=$$(find ~/Library/Developer/Xcode/DerivedData/speaktype-*/Build/Products/Release -name "speaktype.app" -type d 2>/dev/null | head -n 1); \
	if [ -z "$$APP_PATH" ]; then \
		APP_PATH=$$(find build -name "speaktype.app" -type d 2>/dev/null | head -n 1); \
	fi; \
	if [ -z "$$APP_PATH" ]; then \
		echo "❌ Error: Could not find speaktype.app!"; \
		exit 1; \
	fi; \
	echo "✅ Found App at: $$APP_PATH"; \
	if [ ! -f "dmg-assets/dmg-background.png" ]; then \
		echo "Creating background with arrow..."; \
		cd dmg-assets && python3 create-background.py 2>/dev/null || ./create-background.sh 2>/dev/null || echo "Using default"; \
		cd ..; \
	fi; \
	create-dmg \
		--volname "SpeakType" \
		--volicon "speaktype/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" \
		--background "dmg-assets/dmg-background.png" \
		--window-pos 200 120 \
		--window-size 660 400 \
		--icon-size 160 \
		--icon "speaktype.app" 180 170 \
		--hide-extension "speaktype.app" \
		--app-drop-link 480 170 \
		"dist/SpeakType.dmg" \
		"$$APP_PATH"
	@echo "✅ Created dist/SpeakType.dmg"
	@ls -lh dist/SpeakType.dmg

# Prepare release (both ZIP and DMG)
release:
	@echo "🚀 Preparing release..."
	@make clean
	@make package
	@make dmg
	@echo ""
	@echo "✅ Release artifacts ready in dist/"
	@echo "   - SpeakType.zip (for GitHub Releases)"
	@echo "   - SpeakType.dmg (for direct download)"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Create a git tag: git tag v1.0.0"
	@echo "  2. Push tag: git push origin v1.0.0"
	@echo "  3. GitHub Actions will create the release automatically"
	@echo "  OR manually: gh release create v1.0.0 dist/SpeakType.dmg --title 'SpeakType v1.0.0'"

# Generate documentation
docs:
	@echo "Generating documentation..."
	@which jazzy > /dev/null && jazzy || echo "⚠️  Jazzy not installed. Install with: gem install jazzy"

# Open in Xcode
xcode:
	@echo "Opening in Xcode..."
	open speaktype.xcodeproj

# Install to /Applications
install:
	@echo "📦 Installing SpeakType to /Applications..."
	@make build-release
	@APP_PATH=$$(find ~/Library/Developer/Xcode/DerivedData/speaktype-*/Build/Products/Release -name "speaktype.app" -type d 2>/dev/null | head -n 1); \
	if [ -z "$$APP_PATH" ]; then \
		APP_PATH=$$(find build -name "speaktype.app" -type d 2>/dev/null | head -n 1); \
	fi; \
	if [ -z "$$APP_PATH" ]; then \
		echo "❌ Error: Could not find speaktype.app!"; \
		exit 1; \
	fi; \
	echo "✅ Found App at: $$APP_PATH"; \
	rm -rf /Applications/SpeakType.app 2>/dev/null || true; \
	cp -R "$$APP_PATH" /Applications/SpeakType.app; \
	echo "✅ Installed to /Applications/SpeakType.app"

# Full uninstall - removes ALL data and permissions
uninstall:
	@echo "🗑️  Uninstalling SpeakType completely..."
	@pkill -9 speaktype 2>/dev/null || true
	@echo "   Killed running app"
	@tccutil reset Accessibility com.2048labs.speaktype 2>/dev/null || true
	@tccutil reset Microphone com.2048labs.speaktype 2>/dev/null || true
	@echo "   Reset accessibility & microphone permissions"
	@defaults delete com.2048labs.speaktype 2>/dev/null || true
	@rm -rf ~/Library/Application\ Support/SpeakType 2>/dev/null || true
	@rm -rf ~/Library/Preferences/com.2048labs.speaktype.plist 2>/dev/null || true
	@rm -rf ~/Library/Caches/com.2048labs.speaktype 2>/dev/null || true
	@rm -rf ~/Library/Saved\ Application\ State/com.2048labs.speaktype.savedState 2>/dev/null || true
	@echo "   Removed app data and preferences"
	@rm -rf ~/Library/Developer/Xcode/DerivedData/speaktype-* 2>/dev/null || true
	@echo "   Cleared Xcode build cache"
	@rm -rf /Applications/speaktype.app /Applications/SpeakType.app 2>/dev/null || true
	@echo "   Removed installed app"
	@echo "✅ Uninstall complete!"

# Reinstall - uninstall then install
reinstall:
	@echo "🔁 Reinstalling SpeakType..."
	@make uninstall
	@make install

# Quick rebuild - keeps data, just rebuilds and runs
rebuild:
	@echo "🔄 Rebuilding SpeakType (keeping data)..."
	@pkill -9 speaktype 2>/dev/null || true
	@make run

# LOGGING COMMANDS

# View live logs
logs:
	@echo "📱 Streaming SpeakType logs (Ctrl+C to stop)..."
	@echo "Tip: Run 'make run' in another terminal first"
	@echo ""
	log stream --predicate 'process == "speaktype"' --level debug --style compact

# Alias for logs
logs-live: logs

# View recent errors
logs-errors:
	@echo "❌ Recent SpeakType errors (last hour)..."
	@log show --predicate 'process == "speaktype" AND messageType == error' --last 1h --style compact || echo "No errors found"

# View recent logs (last 30 minutes)
logs-recent:
	@echo "📝 Recent SpeakType logs (last 30 minutes)..."
	@log show --predicate 'process == "speaktype"' --last 30m --style compact

# Export logs to Desktop
logs-export:
	@echo "💾 Exporting logs to Desktop..."
	@mkdir -p ~/Desktop/SpeakType_Logs
	@log show --predicate 'process == "speaktype"' --last 1d > ~/Desktop/SpeakType_Logs/app_logs_$(shell date +%Y%m%d_%H%M%S).txt
	@echo "System: $(shell sw_vers -productVersion)" > ~/Desktop/SpeakType_Logs/system_info.txt
	@echo "Date: $(shell date)" >> ~/Desktop/SpeakType_Logs/system_info.txt
	@echo "✅ Logs exported to ~/Desktop/SpeakType_Logs/"
	@open ~/Desktop/SpeakType_Logs/

# Open Console.app filtered to SpeakType
logs-console:
	@echo "Opening Console.app..."
	@open -a Console
