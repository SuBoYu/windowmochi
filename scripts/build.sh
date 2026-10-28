#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
mkdir -p .build/module-cache2 .build/cache
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache2"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache2"
# Some Command Line Tools installations ship two identical SwiftBridging maps.
# Hide only the duplicate through a compiler-local overlay; never edit the SDK.
extra_flags=()
TOOLCHAIN="$(xcode-select -p)/usr/include/swift"
if [[ -f "$TOOLCHAIN/module.modulemap" && -f "$TOOLCHAIN/bridging.modulemap" ]] && /usr/bin/grep -q 'module SwiftBridging' "$TOOLCHAIN/module.modulemap"; then
  echo '// Duplicate map hidden for this build.' > .build/empty.modulemap
  cat > .build/overlay.json <<OVERLAY
{"version":0,"roots":[{"type":"file","name":"$TOOLCHAIN/module.modulemap","external-contents":"$PWD/.build/empty.modulemap"}]}
OVERLAY
  extra_flags=(-vfsoverlay "$PWD/.build/overlay.json")
fi
xcrun swiftc "${extra_flags[@]}" -swift-version 5 -O -target arm64-apple-macosx13.0 -module-cache-path "$PWD/.build/module-cache2" Sources/WindowMochi/*.swift -o .build/WindowMochi
APP="$PWD/dist/WindowMochi.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Sources/WindowMochi/Resources/*.json "$APP/Contents/Resources/"
cp .build/WindowMochi "$APP/Contents/MacOS/WindowMochi"
./scripts/build-icon.sh
cp .build/WindowMochi.icns "$APP/Contents/Resources/WindowMochi.icns"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>WindowMochi</string>
<key>CFBundleIdentifier</key><string>local.windowhabit.app</string>
<key>CFBundleName</key><string>WindowMochi</string>
<key>CFBundleDisplayName</key><string>WindowMochi</string>
<key>CFBundleIconFile</key><string>WindowMochi</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>en</string><string>zh-Hant</string><string>zh-Hans</string><string>ja</string></array>
<key>CFBundleVersion</key><string>5</string>
<key>CFBundleShortVersionString</key><string>0.4.0</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
# Use a persistent certificate when available; never alter the user's keychain automatically.
SIGNING_IDENTITY="${WINDOWMOCHI_SIGNING_IDENTITY:--}"
codesign --force --sign "$SIGNING_IDENTITY" "$APP"
if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  printf 'Note: ad-hoc signing ties Accessibility authorization to this build. Re-add the app after rebuilding if needed.\n'
fi
printf 'Built: %s\n' "$APP"
