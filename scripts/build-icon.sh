#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
SOURCE="assets/branding/windowmochi-mascot-v1.png"
ICONSET="$PWD/.build/WindowMochi.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$SOURCE" --out "$ICONSET/icon_${size}x${size}.png" > /dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$SOURCE" --out "$ICONSET/icon_${size}x${size}@2x.png" > /dev/null
done
iconutil -c icns "$ICONSET" -o .build/WindowMochi.icns
