#!/bin/bash
set -euo pipefail

# ===================================================================
# RackOff DMG Creator
# Creates a pretty drag-to-install DMG for RackOff
# ===================================================================

APP_NAME="RackOff"
DMG_NAME="RackOff-Install"
DMG_VOLUME_NAME="RackOff"
DMG_SIZE="10m"

# Ensure the app exists
if [ ! -d "$APP_NAME.app" ]; then
    echo "❌ $APP_NAME.app not found. Run ./build.sh first!"
    exit 1
fi

echo "📦 Creating DMG for $APP_NAME..."

SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: Pablo Alvarado (V433H655PN)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-AC_PASSWORD}"

# Clean previous DMG artifacts
rm -rf "$DMG_NAME.dmg" dmg-staging

# Notarize & staple RackOff.app BEFORE packing the DMG so the app bundle itself
# carries an offline ticket inside /Applications.
if [ "${SKIP_NOTARIZE:-0}" != "1" ] && xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "🔐 Submitting $APP_NAME.app for notarization before DMG packaging..."
    APP_ZIP="${APP_NAME}-notarize.zip"
    ditto -c -k --keepParent "$APP_NAME.app" "$APP_ZIP"
    xcrun notarytool submit "$APP_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
    rm -f "$APP_ZIP"
    xcrun stapler staple "$APP_NAME.app"
    xcrun stapler validate "$APP_NAME.app"
fi

# Create staging directory (explicitly 0755 so volume root is world-readable)
mkdir -p dmg-staging
chmod 0755 dmg-staging
ditto "$APP_NAME.app" "dmg-staging/$APP_NAME.app"

# Create a symbolic link to /Applications for drag-to-install
ln -s /Applications dmg-staging/Applications
chmod -R u+rwX,go+rX dmg-staging
chmod 0755 dmg-staging

# Create the DMG
hdiutil create \
    -volname "$DMG_VOLUME_NAME" \
    -srcfolder dmg-staging \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_NAME.dmg"

# Clean up staging
rm -rf dmg-staging

# Sign the DMG so it can be notarized and stapled.
echo "🔏 Signing DMG..."
codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG_NAME.dmg"
codesign --verify --verbose "$DMG_NAME.dmg"

if [ "${SKIP_NOTARIZE:-0}" != "1" ] && xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "🔐 Submitting $DMG_NAME.dmg for notarization..."
    xcrun notarytool submit "$DMG_NAME.dmg" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG_NAME.dmg"
    xcrun stapler validate "$DMG_NAME.dmg"
fi

if [ -x "$HOME/.claude/scripts/dev-tools/dmg-doctor" ]; then
    "$HOME/.claude/scripts/dev-tools/dmg-doctor" "$DMG_NAME.dmg"
fi

echo ""
echo "✨ DMG created: $DMG_NAME.dmg"
echo ""
echo "To install:"
echo "  1. Double-click $DMG_NAME.dmg"
echo "  2. Drag RackOff to Applications"
echo "  3. Eject the DMG"
echo "  4. Launch RackOff from Applications"
echo ""
echo "Or quick-install from terminal:"
echo "  hdiutil attach $DMG_NAME.dmg && cp -r /Volumes/$DMG_VOLUME_NAME/$APP_NAME.app /Applications/ && hdiutil detach /Volumes/$DMG_VOLUME_NAME"
