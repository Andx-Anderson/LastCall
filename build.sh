#!/bin/bash
# Build, bundle, sign and install Last Call.
#
# The tccutil reset matters: the bundle is ad-hoc signed, so its Accessibility
# grant is keyed to the code hash. Every rebuild invalidates it, and macOS does
# NOT tell you — the row still shows as enabled while the app is silently denied.
# Resetting forces a fresh prompt instead of a mystery.

set -e
cd "$(dirname "$0")"

APP_ID="com.andxlab.lastcall"
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
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>MIT</string>
</dict>
</plist>
PLIST
plutil -lint "$STAGE/Contents/Info.plist" >/dev/null

echo "==> signing (ad-hoc)"
codesign --force --sign - "$STAGE"

echo "==> clearing the stale Accessibility grant (the hash just changed)"
tccutil reset Accessibility "$APP_ID" || true

echo "==> installing"
pkill -f "LastCall.app/Contents/MacOS" 2>/dev/null || true
sleep 1
ditto "$STAGE" "$DEST"
codesign -v "$DEST"

echo "==> launching"
open "$DEST"
echo
echo "Done. Grant Accessibility to Last Call when prompted."
