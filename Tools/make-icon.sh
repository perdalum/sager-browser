#!/bin/bash
# Renders Resources/AppIcon.icns from Tools/make-icon.swift.
#
#   ./Tools/make-icon.sh
#
# The artwork is drawn at every iconset size instead of being downsampled, so
# the 16px and 32px versions stay crisp. Intermediate PNGs go to .build/.
set -euo pipefail
cd "$(dirname "$0")/.."

ICONSET=".build/AppIcon.iconset"
BINARY=".build/make-icon"

rm -rf "$ICONSET"
mkdir -p "$ICONSET"

echo "==> compiling the drawing tool"
swiftc -O -module-cache-path .build/module-cache Tools/make-icon.swift -o "$BINARY"

render() {
    "$BINARY" "$1" "$ICONSET/$2"
}

echo "==> rendering iconset"
render 16   icon_16x16.png
render 32   icon_16x16@2x.png
render 32   icon_32x32.png
render 64   icon_32x32@2x.png
render 128  icon_128x128.png
render 256  icon_128x128@2x.png
render 256  icon_256x256.png
render 512  icon_256x256@2x.png
render 512  icon_512x512.png
render 1024 icon_512x512@2x.png

echo "==> packing Resources/AppIcon.icns"
mkdir -p Resources
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns

# Kept in the repo so the README can show it and it can be previewed on its own.
cp "$ICONSET/icon_512x512@2x.png" Resources/icon-1024.png

ls -lh Resources/AppIcon.icns Resources/icon-1024.png
