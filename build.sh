#!/bin/bash
# Build, bundle, sign and install Last Call.
#
# Signed with a real Developer ID, so the signing identity is stable across
# rebuilds and the Accessibility grant survives them. That is why there is no
# tccutil reset here any more: with ad-hoc signing every rebuild changed the code
# hash and silently voided the grant.

set -e
cd "$(dirname "$0")"

APP_ID="com.andxlab.lastcall"
VERSION="$(cat VERSION)"   # single source of truth
# Auto-detected from the keychain so no identity is hardcoded here. Override with
# SIGN_ID=... if you have more than one. Falls back to ad-hoc signing.
SIGN_ID="${SIGN_ID:-$(security find-identity -v -p codesigning 2>/dev/null \
  | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)"/\1/')}"
SIGN_ID="${SIGN_ID:--}"
STAGE="build/LastCall.app"
DEST="/Applications/LastCall.app"

echo "==> compiling"
swiftc -O -o lastcall Sources/*.swift

echo "==> bundling"
mkdir -p "$STAGE/Contents/MacOS" "$STAGE/Contents/Resources"
cp lastcall "$STAGE/Contents/MacOS/LastCall"
cp Icon/AppIcon.icns "$STAGE/Contents/Resources/AppIcon.icns"
cat > "$STAGE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Last Call</string>
    <key>CFBundleDisplayName</key><string>Last Call</string>
    <key>CFBundleIdentifier</key><string>${APP_ID}</string>
    <key>CFBundleExecutable</key><string>LastCall</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>MIT</string>
</dict>
</plist>
PLIST
plutil -lint "$STAGE/Contents/Info.plist" >/dev/null

echo "==> signing (Developer ID, hardened runtime)"
# --options runtime and --timestamp are both required for notarisation.
codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$STAGE"
codesign -dv --verbose=2 "$STAGE" 2>&1 | grep -E "Authority=Developer ID|flags="

echo "==> installing"
pkill -f "LastCall.app/Contents/MacOS" 2>/dev/null || true
sleep 1
ditto "$STAGE" "$DEST"
codesign -v "$DEST"

echo "==> launching"
open "$DEST"
echo
echo "Done. Grant Accessibility to Last Call if this is a first install;"
echo "an existing grant survives rebuilds now that it is Developer ID signed."
