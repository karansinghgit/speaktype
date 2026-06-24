#!/bin/bash
# create-release.sh — Bump version, build, sign, notarize, and produce a DMG in dist/
# Usage: ./scripts/create-release.sh [version]
#        If no version is given, patch version is auto-bumped.
#
# After this script succeeds, run ./scripts/deploy-release.sh to push to GitHub.

set -e

source "$(dirname "$0")/lib/common.sh"

echo "🚀 SpeakType Release Builder"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Preflight ─────────────────────────────────────────────────────────────────
require_repo_root
require_clean_tree

# ── Step 1: Determine version ──────────────────────────────────────────────────
VERSION="$(resolve_version "${1:-}")"
echo "📦 Releasing v${VERSION}"
echo ""

# ── Step 2: Bump version in project ───────────────────────────────────────────
echo "🔢 Updating version numbers..."
perl -0pi -e "s/(MARKETING_VERSION = )[^;]+;/\${1}${VERSION};/g" "$PROJECT_FILE"

CURRENT_BUILD=$(perl -ne 'print $1 and exit if /CURRENT_PROJECT_VERSION = (\d+);/' "$PROJECT_FILE")
NEXT_BUILD=$((CURRENT_BUILD + 1))
perl -0pi -e "s/(CURRENT_PROJECT_VERSION = )\d+;/\${1}${NEXT_BUILD};/g" "$PROJECT_FILE"

echo "  Version : v${VERSION}"
echo "  Build   : ${NEXT_BUILD}"

# ── Step 3: Update CHANGELOG ──────────────────────────────────────────────────
if [ -f "$CHANGELOG" ]; then
  echo ""
  echo "📝 Updating CHANGELOG..."
  RELEASE_DATE=$(date +%Y-%m-%d)
  perl -0pi -e "s/## \[Unreleased\]\n- \n/## [Unreleased]\n- \n\n## [${VERSION}] - ${RELEASE_DATE}\n- \n/" "$CHANGELOG"
fi

# ── Step 4: Commit + tag (local only) ─────────────────────────────────────────
echo ""
echo "💾 Creating release commit + tag (local only)..."
git add "$PROJECT_FILE" "$CHANGELOG"
git commit -m "release: v${VERSION}"
git tag "v${VERSION}"
echo "📌 Tagged: v${VERSION}"

# ── Step 5: Check notarization credentials ────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔐 Checking notarization credentials..."
echo ""
ensure_notary_credentials

# ── Step 6: Build ─────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🏗️  Building Release..."
echo ""

xcodebuild -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
  ENABLE_HARDENED_RUNTIME=YES \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime" \
  clean build

APP_PATH="build/Build/Products/Release/speaktype.app"
[ -z "$APP_PATH" ] && { echo "❌ Could not find speaktype.app!"; exit 1; }
[ -d "$APP_PATH" ] || { echo "❌ Release app not found at $APP_PATH"; exit 1; }

BUILT_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP_PATH/Contents/Info.plist")
if [ "$BUILT_BUNDLE_ID" != "$APP_BUNDLE_ID" ]; then
  echo "❌ Refusing to package unexpected app bundle: $BUILT_BUNDLE_ID"
  exit 1
fi

echo ""
echo "🔍 Verifying app signature..."
codesign --verify --deep --strict "$APP_PATH"
echo "✅ App signature verified"

# ── Step 7: Create + sign DMG ─────────────────────────────────────────────────
mkdir -p dist
DMG_NAME="SpeakType-${VERSION}.dmg"
DMG_PATH="dist/${DMG_NAME}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💿 Creating DMG..."

if [ ! -f "dmg-assets/dmg-background.png" ]; then
  cd dmg-assets
  python3 create-background.py 2>/dev/null || ./create-background.sh 2>/dev/null || echo "⚠️  Using default background"
  cd ..
fi

[ -f "$DMG_PATH" ] && rm "$DMG_PATH"

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
  "$DMG_PATH" \
  "$APP_PATH"

echo ""
echo "🔐 Signing DMG..."
codesign --sign "$SIGN_IDENTITY" --force --timestamp --options runtime "$DMG_PATH"
codesign --verify --deep --strict "$DMG_PATH"
echo "✅ DMG signed"

# ── Step 8: Notarize + staple ─────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔒 Submitting for notarization (2-5 min)..."
echo ""

SUBMIT_OUTPUT=$(xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait 2>&1)

echo "$SUBMIT_OUTPUT"
SUBMISSION_ID=$(echo "$SUBMIT_OUTPUT" | grep -E '^\s*id:' | head -1 | awk '{print $2}')

if echo "$SUBMIT_OUTPUT" | grep -q "status: Accepted"; then
  echo ""
  echo "📎 Stapling notarization ticket..."
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"

  echo ""
  echo "🔍 Final Gatekeeper check..."
  spctl --assess --type open --context context:primary-signature --verbose "$DMG_PATH" || true

  # Write a small metadata file so deploy-release.sh can pick up the version/path
  echo "${VERSION}" > dist/.release-version
  echo "${DMG_PATH}"  > dist/.release-dmg

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🎉  Release built successfully!"
  echo "    DMG: ${DMG_PATH}"
  echo ""
  echo "Next step → push to GitHub:"
  echo "    ./scripts/deploy-release.sh"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
  echo ""
  echo "❌ Notarization failed!"
  if [ -n "$SUBMISSION_ID" ]; then
    echo ""
    echo "Fetching detailed logs..."
    xcrun notarytool log "$SUBMISSION_ID" --keychain-profile "$NOTARY_PROFILE"
  fi
  exit 1
fi
