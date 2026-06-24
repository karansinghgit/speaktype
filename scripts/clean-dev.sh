#!/bin/bash

# Complete cleanup script for both dev and release builds
# Removes all app data and permissions for fresh testing

set -e

source "$(dirname "$0")/lib/common.sh"

echo "🧹 Cleaning SpeakType (dev + release)..."
echo ""

# Kill ALL running instances (both dev and release)
pkill -9 -i speaktype 2>/dev/null || true
killall "SpeakType" 2>/dev/null || true
killall "speaktype" 2>/dev/null || true
sleep 1
echo "✅ Killed all running instances"

# Reset ALL permissions
tccutil reset Microphone ${APP_BUNDLE_ID} 2>/dev/null || true
tccutil reset Accessibility ${APP_BUNDLE_ID} 2>/dev/null || true
tccutil reset Microphone ${APP_BUNDLE_ID}.dev 2>/dev/null || true
tccutil reset Accessibility ${APP_BUNDLE_ID}.dev 2>/dev/null || true
echo "✅ Reset microphone & accessibility permissions"

# Remove app preferences and data
defaults delete ${APP_BUNDLE_ID} 2>/dev/null || true
defaults delete ${APP_BUNDLE_ID}.dev 2>/dev/null || true
rm -rf ~/Library/Caches/${APP_BUNDLE_ID} 2>/dev/null || true
rm -rf ~/Library/Caches/${APP_BUNDLE_ID}.dev 2>/dev/null || true
rm -rf ~/Library/Saved\ Application\ State/${APP_BUNDLE_ID}.savedState 2>/dev/null || true
rm -rf ~/Library/Saved\ Application\ State/${APP_BUNDLE_ID}.dev.savedState 2>/dev/null || true
rm -rf ~/Library/Preferences/${APP_BUNDLE_ID}.plist 2>/dev/null || true
rm -rf ~/Library/Preferences/${APP_BUNDLE_ID}.dev.plist 2>/dev/null || true
rm -rf ~/Library/Application\ Support/SpeakType 2>/dev/null || true
rm -rf ~/Library/Application\ Support/SpeakType-Dev 2>/dev/null || true
echo "✅ Removed app preferences & data"

# Remove BOTH dev and release installed versions
rm -rf /Applications/speaktype.app 2>/dev/null || true
rm -rf /Applications/SpeakType.app 2>/dev/null || true
rm -rf ~/Applications/SpeakType-Dev.app 2>/dev/null || true
echo "✅ Removed dev & release apps"

echo ""
echo "✨ Clean complete!"
echo ""
echo "Next steps:"
echo "  • Dev: make run"
echo "  • Dev (separate app): make run-dev"
echo "  • Release: Install from DMG"
echo ""
