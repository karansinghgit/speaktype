#!/bin/bash

set -euo pipefail

APP_NAME="SpeakType-Dev"
BUNDLE_ID="com.2048labs.speaktype.dev"
DERIVED_DATA_PATH="$PWD/build/dev-derived"
BUILD_PRODUCTS_PATH="$DERIVED_DATA_PATH/Build/Products/Debug"
DEST_APP_PATH="$HOME/Applications/${APP_NAME}.app"

if [ ! -f "speaktype.xcodeproj/project.pbxproj" ]; then
  echo "Error: run this script from the project root."
  exit 1
fi

mkdir -p "$HOME/Applications"

echo "Building ${APP_NAME} from current checkout..."
xcodebuild \
  -project speaktype.xcodeproj \
  -scheme speaktype \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  APP_DISPLAY_NAME="$APP_NAME" \
  build

BUILD_APP_PATH="$(find "$BUILD_PRODUCTS_PATH" -maxdepth 1 -name "*.app" -type d | head -n 1)"
if [ -z "$BUILD_APP_PATH" ] || [ ! -d "$BUILD_APP_PATH" ]; then
  echo "Error: built app not found in $BUILD_PRODUCTS_PATH"
  exit 1
fi

echo "Installing ${APP_NAME} to $DEST_APP_PATH..."
mkdir -p "$DEST_APP_PATH"
rsync -a --delete "$BUILD_APP_PATH/" "$DEST_APP_PATH/"

DEV_PROCESS_PATH="$DEST_APP_PATH/Contents/MacOS/speaktype"
if pgrep -f "$DEV_PROCESS_PATH" >/dev/null 2>&1; then
  echo "Stopping existing ${APP_NAME} instance..."
  pkill -f "$DEV_PROCESS_PATH" || true
  sleep 1
fi

# Prevent duplicate menu bar items while developing by stopping installed app variants.
for PROD_PATH in "/Applications/speaktype.app/Contents/MacOS/speaktype" "/Applications/SpeakType.app/Contents/MacOS/speaktype"; do
  if pgrep -f "$PROD_PATH" >/dev/null 2>&1; then
    echo "Stopping running production SpeakType instance at $PROD_PATH..."
    pkill -f "$PROD_PATH" || true
    sleep 1
  fi
done

echo "Launching ${APP_NAME}..."
open "$DEST_APP_PATH"

echo ""
echo "Bundle ID: $BUNDLE_ID"
echo "App Path : $DEST_APP_PATH"
