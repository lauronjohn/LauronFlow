#!/bin/bash
# Builds LauronFlow and installs it to /Applications, replacing any existing copy.
set -euo pipefail

cd "$(dirname "$0")"
REPO_DIR="$(pwd)"

APP_NAME="LauronFlow.app"
DEST="/Applications/$APP_NAME"
SUPPORT_DIR="$HOME/Library/Application Support/LauronFlow"

echo "==> Checking prerequisites..."
for cmd in xcodegen uv ffmpeg; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing dependency: $cmd (see README.md for setup instructions)." >&2
    exit 1
  fi
done
if [ ! -d "$REPO_DIR/sidecar" ]; then
  echo "sidecar/ not found next to this script — see README.md for the expected layout." >&2
  exit 1
fi
if ! security find-identity -v -p codesigning | grep -q "LauronFlow Local Dev"; then
  echo "No 'LauronFlow Local Dev' signing certificate found in your keychain." >&2
  echo "See README.md for how to create a one-time local self-signed certificate." >&2
  exit 1
fi

echo "==> Recording sidecar location for this machine..."
mkdir -p "$SUPPORT_DIR"
printf '%s' "$REPO_DIR/sidecar" > "$SUPPORT_DIR/sidecar_path.txt"

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
