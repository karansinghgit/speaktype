#!/bin/bash

# Development cleanup script
# Removes all app data and permissions for fresh testing

set -e

echo "🧹 Cleaning SpeakType development environment..."

# Kill running app
pkill -9 speaktype 2>/dev/null || true
echo "✅ Killed running app"

# Reset accessibility permissions
tccutil reset Accessibility com.2048labs.speaktype 2>/dev/null || true
echo "✅ Reset accessibility permissions"

# Remove app preferences and data
defaults delete com.2048labs.speaktype 2>/dev/null || true
rm -rf ~/Library/Caches/com.2048labs.speaktype 2>/dev/null || true
rm -rf ~/Library/Saved\ Application\ State/com.2048labs.speaktype.savedState 2>/dev/null || true
rm -rf ~/Library/Preferences/com.2048labs.speaktype.plist 2>/dev/null || true
echo "✅ Removed app preferences"

# Remove app data (skip Containers due to permissions)
rm -rf ~/Library/Application\ Support/SpeakType 2>/dev/null || true
echo "✅ Removed app data"

# Remove old installed versions
rm -rf /Applications/speaktype.app 2>/dev/null || true
echo "✅ Removed installed app"

echo ""
echo "✨ Clean complete! Run 'make build' or 'make run' to start fresh."
