#!/bin/bash
# Builds SagerBrowser and wraps the binary in a minimal .app bundle,
# so it launches as a normal windowed app (menu bar, Dock, focus).
#
# SWIFT_FLAGS can pass extra flags to every `swift build` call, e.g.
#   SWIFT_FLAGS="--disable-sandbox --cache-path .build/spm-cache --scratch-path .build" ./build.sh
# Needed only in restricted/sandboxed shells where SwiftPM cannot write
# ~/Library caches or apply its own (nested) build sandbox.
set -euo pipefail

cd "$(dirname "$0")"

CONFIG="${CONFIG:-release}"
APP_NAME="SagerBrowser"
APP="$PWD/$APP_NAME.app"
SWIFT_FLAGS="${SWIFT_FLAGS:-}"

# shellcheck disable=SC2086
BUILD_FLAGS=(-c "$CONFIG" $SWIFT_FLAGS)

echo "==> swift build ${BUILD_FLAGS[*]}"
swift build "${BUILD_FLAGS[@]}"

BIN_PATH="$(swift build "${BUILD_FLAGS[@]}" --show-bin-path)/$APP_NAME"

echo "==> assembling $APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH" "$APP/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"

if [ -f Resources/AppIcon.icns ]; then
    cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
else
    echo "   (no Resources/AppIcon.icns — run ./Tools/make-icon.sh for the icon)"
fi

# Ad-hoc signature: enough for local use and keeps Gatekeeper quiet.
codesign --force --sign - "$APP" >/dev/null 2>&1 || echo "   (codesign skipped)"

echo "==> built $APP"
echo "    open \"$APP\""
