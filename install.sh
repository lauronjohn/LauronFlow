#!/bin/bash
# Builds LauronFlow and installs it to /Applications, replacing any existing copy.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="LauronFlow.app"
DEST="/Applications/$APP_NAME"

echo "==> Generating Xcode project..."
xcodegen generate

echo "==> Building (Debug)..."
xcodebuild -project LauronFlow.xcodeproj -scheme LauronFlow -configuration Debug build | tail -5

BUILT_PRODUCTS_DIR=$(xcodebuild -project LauronFlow.xcodeproj -scheme LauronFlow -configuration Debug \
  -showBuildSettings 2>/dev/null | awk -F'= ' '/ BUILT_PRODUCTS_DIR /{print $2; exit}')
BUILT_APP="$BUILT_PRODUCTS_DIR/$APP_NAME"

if [ ! -d "$BUILT_APP" ]; then
  echo "Build succeeded but $BUILT_APP not found." >&2
  exit 1
fi

echo "==> Quitting any running instance..."
osascript -e 'tell application id "com.lauronjohn.LauronFlow" to quit' >/dev/null 2>&1 || true
sleep 1

echo "==> Installing to $DEST..."
rm -rf "$DEST"
ditto "$BUILT_APP" "$DEST"

echo "==> Launching..."
open "$DEST"

echo "Done. Installed at $DEST"
