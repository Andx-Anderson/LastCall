#!/bin/bash
# Package a .dmg for a GitHub release.
#
# The app is ad-hoc signed, so whoever downloads it gets Gatekeeper's
# "unidentified developer" warning and has to clear the quarantine flag before it
# will open. That is explained in the README rather than glossed over — see the
# "Download" section.

set -e
cd "$(dirname "$0")"

VERSION="${1:?usage: ./release.sh <version>   e.g. ./release.sh 1.1.0}"
APP="build/LastCall.app"
DMG_DIR="build/dmg"
DMG="build/LastCall-${VERSION}.dmg"

echo "==> building the app"
swiftc -O -o lastcall Sources/*.swift
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp lastcall "$APP/Contents/MacOS/LastCall"
cp Icon/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Last Call</string>
    <key>CFBundleDisplayName</key><string>Last Call</string>
    <key>CFBundleIdentifier</key><string>com.andxlab.lastcall</string>
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
plutil -lint "$APP/Contents/Info.plist" >/dev/null
codesign --force --sign - "$APP"
codesign -v "$APP"

echo "==> staging the disk image"
if [ -d "$DMG_DIR" ]; then mv "$DMG_DIR" "$HOME/.Trash/LastCall-dmg-stage-$(date +%s)"; fi
mkdir -p "$DMG_DIR"
ditto "$APP" "$DMG_DIR/LastCall.app"
ln -s /Applications "$DMG_DIR/Applications"

echo "==> creating $DMG"
if [ -f "$DMG" ]; then mv "$DMG" "$HOME/.Trash/$(basename "$DMG").$(date +%s)"; fi
hdiutil create -volname "Last Call" -srcfolder "$DMG_DIR" -ov -format UDZO "$DMG" >/dev/null

echo
echo "Built $DMG ($(du -h "$DMG" | cut -f1))"
echo "Upload with:  gh release upload v${VERSION} \"$DMG\" --clobber"
