# Makefile for SpeakType

.PHONY: help build clean test lint format run setup

# Default target
help:
	@echo "SpeakType - Available commands:"
	@echo "  make setup    - Initial project setup"
	@echo "  make build    - Build the project"
	@echo "  make run      - Run the application"
	@echo "  make test     - Run all tests"
	@echo "  make lint     - Run SwiftLint"
	@echo "  make format   - Format code with SwiftLint"
	@echo "  make clean    - Clean build artifacts"

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

# Generate documentation
docs:
	@echo "Generating documentation..."
	@which jazzy > /dev/null && jazzy || echo "⚠️  Jazzy not installed. Install with: gem install jazzy"

# Open in Xcode
xcode:
	@echo "Opening in Xcode..."
	open speaktype.xcodeproj

