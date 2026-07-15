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

# Clean previous DMG artifacts
rm -rf "$DMG_NAME.dmg" dmg-staging

# Create staging directory
mkdir -p dmg-staging
cp -r "$APP_NAME.app" dmg-staging/

# Create a symbolic link to /Applications for drag-to-install
ln -s /Applications dmg-staging/Applications

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
