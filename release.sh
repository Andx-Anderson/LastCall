#!/bin/bash
# Package a .dmg for a GitHub release.
#
# Signs with Developer ID, notarises with Apple, and staples the ticket, so a
# downloaded copy opens with no warning and no quarantine dance.
#
# Notarisation uses the same App Store Connect API key that ships Vantage — no
# Apple ID, no password. (That key can notarise but cannot CREATE a Developer ID
# certificate; only the Account Holder can, which is why the cert was made by hand.)

set -e
cd "$(dirname "$0")"

# Version comes from the VERSION file; an argument overrides it.
VERSION="${1:-$(cat VERSION)}"
APP="build/LastCall.app"
# Nothing identifying is hardcoded. The signing identity is read from the
# keychain; the notarisation credentials come from the environment.
SIGN_ID="${SIGN_ID:-$(security find-identity -v -p codesigning 2>/dev/null \
  | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)"/\1/')}"
: "${SIGN_ID:?no Developer ID Application identity found in the keychain}"

# Set these in your shell (see README). ASC_KEY is the path to the .p8.
: "${ASC_KEY:?set ASC_KEY to your App Store Connect .p8 key path}"
: "${ASC_KEY_ID:?set ASC_KEY_ID}"
: "${ASC_ISSUER:?set ASC_ISSUER}"
DMG_DIR="build/dmg"
# Versionless on purpose: releases/latest/download/LastCall.dmg then always
# resolves, so the README link never needs editing for a new release.
DMG="build/LastCall.dmg"

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
codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$APP"
codesign -v "$APP"
codesign -dv --verbose=2 "$APP" 2>&1 | grep -E "Authority=Developer ID Application|flags="

echo "==> notarising the app"
ditto -c -k --keepParent "$APP" "build/LastCall-app.zip"
xcrun notarytool submit "build/LastCall-app.zip" \
  --key "$ASC_KEY" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER" --wait
xcrun stapler staple "$APP"

echo "==> staging the disk image"
if [ -d "$DMG_DIR" ]; then mv "$DMG_DIR" "$HOME/.Trash/LastCall-dmg-stage-$(date +%s)"; fi
mkdir -p "$DMG_DIR"
ditto "$APP" "$DMG_DIR/LastCall.app"
ln -s /Applications "$DMG_DIR/Applications"

echo "==> creating $DMG"
if [ -f "$DMG" ]; then mv "$DMG" "$HOME/.Trash/$(basename "$DMG").$(date +%s)"; fi
hdiutil create -volname "Last Call" -srcfolder "$DMG_DIR" -ov -format UDZO "$DMG" >/dev/null

# The disk image must be SIGNED before it is notarised. A notarised-but-unsigned
# dmg staples fine and still fails Gatekeeper with "no usable signature" — the app
# inside is fine, but the image itself warns on open.
echo "==> signing the disk image"
codesign --force --sign "$SIGN_ID" --timestamp "$DMG"
codesign -v "$DMG"

echo "==> notarising the disk image"
xcrun notarytool submit "$DMG" \
  --key "$ASC_KEY" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER" --wait
xcrun stapler staple "$DMG"

echo
echo "==> final verdict (want: accepted / Notarized Developer ID)"
spctl -a -vvv -t open --context context:primary-signature "$DMG" 2>&1 | tail -3

echo
echo "Built $DMG ($(du -h "$DMG" | cut -f1))"
echo "Upload with:  gh release upload v${VERSION} \"$DMG\" --clobber"
