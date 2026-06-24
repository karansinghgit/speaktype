#!/bin/bash
# deploy-release.sh — Push a locally-built release to GitHub.
# Usage: ./scripts/deploy-release.sh [version]
#
# Run AFTER create-release.sh has succeeded.
# If no version is given, reads from dist/.release-version written by create-release.sh.

set -e

source "$(dirname "$0")/lib/common.sh"

echo "🚀 SpeakType Release Deployer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Resolve version ────────────────────────────────────────────────────────────
if [ -n "$1" ]; then
  VERSION="$1"
else
  if [ ! -f "dist/.release-version" ]; then
    echo "❌ No version specified and dist/.release-version not found."
    echo "   Run ./scripts/create-release.sh first, or pass the version explicitly:"
    echo "   ./scripts/deploy-release.sh 1.2.3"
    exit 1
  fi
  VERSION=$(cat dist/.release-version)
fi

echo "📦 Deploying v${VERSION}"

# ── Resolve DMG path ───────────────────────────────────────────────────────────
if [ -f "dist/.release-dmg" ]; then
  DMG_PATH=$(cat dist/.release-dmg)
else
  # Fall back to the conventional name
  DMG_PATH="dist/SpeakType-${VERSION}.dmg"
fi

if [ ! -f "$DMG_PATH" ]; then
  echo "❌ DMG not found at: ${DMG_PATH}"
  echo "   Run ./scripts/create-release.sh first."
  exit 1
fi

echo "💿 DMG     : ${DMG_PATH}"
echo "🏷️  Tag     : v${VERSION}"
echo ""

# ── Verify tag exists locally ──────────────────────────────────────────────────
if ! git rev-parse "v${VERSION}" &>/dev/null; then
  echo "❌ Local tag v${VERSION} not found."
  echo "   Run ./scripts/create-release.sh to create the release commit and tag first."
  exit 1
fi

# ── Push commits + tag ────────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔼 Pushing commits and tag to GitHub..."
git push origin HEAD
git push origin "v${VERSION}"
echo "✅ Pushed"

# ── Create GitHub Release with DMG ────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📤 Creating GitHub Release and uploading DMG..."

if ! command -v gh &>/dev/null; then
  echo "❌ GitHub CLI (gh) not installed. Install with: brew install gh"
  exit 1
fi

# Build release notes from git log between previous tag and this one
PREV_TAG=$(git tag --sort=-version:refname | grep -v "v${VERSION}" | head -1)
if [ -n "$PREV_TAG" ]; then
  NOTES=$(git log "${PREV_TAG}..v${VERSION}" \
    --pretty=format:"- %s" \
    | grep -v "^- release:" \
    | grep -v "^- update build" \
    | grep -v "^- docs:" \
    | grep -v "^- chore:")
else
  NOTES="Initial release"
fi

# Fall back to --generate-notes if we end up with nothing
if [ -z "$NOTES" ]; then
  gh release create "v${VERSION}" "$DMG_PATH" \
    --title "SpeakType v${VERSION}" \
    --generate-notes \
    --latest
else
  gh release create "v${VERSION}" "$DMG_PATH" \
    --title "SpeakType v${VERSION}" \
    --notes "$NOTES" \
    --latest
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉  v${VERSION} is live!"
echo "    https://github.com/${GITHUB_REPO}/releases/tag/v${VERSION}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Clean up marker files
rm -f dist/.release-version dist/.release-dmg
