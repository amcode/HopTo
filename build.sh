#!/bin/bash
# Builds "Hop To.app" into ./dist. Requires Xcode Command Line Tools (xcode-select --install).
#
#   ./build.sh                     # ad-hoc signed, version from Info.plist
#   VERSION=1.2.0 ./build.sh       # stamp a specific version (the release workflow passes the git tag)
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./build.sh   # proper signing
set -euo pipefail
cd "$(dirname "$0")"

APP="dist/Hop To.app"
rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "→ Running tests…"
swift test

echo "→ Building universal binary…"
swift build -c release --arch arm64 --arch x86_64
cp ".build/apple/Products/Release/HopTo" "$APP/Contents/MacOS/HopTo"

echo "→ Assembling bundle…"
cp Info.plist "$APP/Contents/Info.plist"
if [[ -n "${VERSION:-}" ]]; then
  BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"
  echo "   version $VERSION ($BUILD_NUMBER)"
fi
iconutil -c icns AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  echo "→ Signing with Developer ID (hardened runtime)…"
  codesign --force --deep --options runtime --timestamp \
    --entitlements HopTo.entitlements \
    --sign "$SIGN_IDENTITY" "$APP"
  codesign --verify --deep --strict --verbose=2 "$APP"
else
  echo "→ Signing (ad hoc)…"
  codesign --force --deep --sign - "$APP"
fi

echo "✓ Built $APP"
