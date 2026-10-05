#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/Lumen for Mac.app"

cd "$ROOT"
swift build -c release
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/.build/release/LumenMac" "$APP/Contents/MacOS/LumenMac"
cp "$ROOT/macos/Info.plist" "$APP/Contents/Info.plist"
SIGNING_IDENTITY="${LUMEN_SIGNING_IDENTITY:-Lumen Local Code Signing}"
/usr/bin/codesign --force --deep --options runtime --timestamp=none --sign "$SIGNING_IDENTITY" "$APP"
/usr/bin/codesign --verify --deep --strict "$APP"
printf 'Built %s\n' "$APP"
