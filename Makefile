# Makefile for SpeakType

.PHONY: help build clean test lint format run setup logs logs-live logs-errors logs-export

# Default target
help:
	@echo "SpeakType - Available commands:"
	@echo ""
	@echo "Development:"
	@echo "  make setup         - Initial project setup"
	@echo "  make build         - Build the project (Debug)"
	@echo "  make run           - Run the application"
	@echo "  make clean         - Clean build artifacts"
	@echo "  make xcode         - Open in Xcode"
	@echo ""
	@echo "Testing:"
	@echo "  make test          - Run all tests"
	@echo "  make test-unit     - Run unit tests only"
	@echo "  make test-ui       - Run UI tests only"
	@echo ""
	@echo "Distribution:"
	@echo "  make release       - 🚀 Build ZIP + DMG for distribution"
	@echo "  make package       - Create ZIP package"
	@echo "  make dmg           - Create DMG installer"
	@echo "  ./scripts/create-release.sh - Interactive release creator"
	@echo ""
	@echo "Code Quality:"
	@echo "  make lint          - Run SwiftLint"
	@echo "  make format        - Format code with SwiftLint"
	@echo ""
	@echo "Logging:"
	@echo "  make logs          - View live logs"
	@echo "  make logs-live     - Stream live logs (alias)"
	@echo "  make logs-errors   - View recent errors"
	@echo "  make logs-export   - Export last 24h logs to Desktop"
	@echo ""
	@echo "📚 For detailed release instructions, see: RELEASING.md"

# Project setup
setup:
	@echo "Setting up project..."
	@which swiftlint > /dev/null || echo "⚠️  SwiftLint not installed. Install with: brew install swiftlint"
	@echo "✅ Setup complete!"

# Build the project
build:
	@echo "Building SpeakType..."
	xcodebuild -scheme speaktype -configuration Debug build

# Build for release
build-release:
	@echo "Building SpeakType (Release)..."
	xcodebuild -scheme speaktype -configuration Release build

# Run the application
run:
	@echo "Running SpeakType..."
	xcodebuild -scheme speaktype -configuration Debug build
	open build/Debug/speaktype.app

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
	@if command -v create-dmg > /dev/null; then \
		create-dmg \
			--volname "SpeakType" \
			--volicon "speaktype/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" \
			--window-pos 200 120 \
			--window-size 800 400 \
			--icon-size 100 \
			--hide-extension "speaktype.app" \
			--app-drop-link 600 185 \
			"dist/SpeakType.dmg" \
			"build/Release/speaktype.app"; \
	else \
		hdiutil create -volname "SpeakType" -srcfolder build/Release/speaktype.app -ov -format UDZO dist/SpeakType.dmg; \
	fi
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

