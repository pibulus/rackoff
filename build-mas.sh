#!/bin/bash

# ===================================================================
# RackOff Mac App Store build (ported from Spellbreak/NibNab pattern)
# Builds the app, embeds a provisioning profile, re-signs with Apple
# Distribution, and packages a .pkg with the installer certificate.
#
# Requires (none of these exist yet — Pablo must create them):
#   - "Apple Distribution: Pablo Alvarado (V433H655PN)" cert
#   - "3rd Party Mac Developer Installer: Pablo Alvarado (V433H655PN)" cert
#   - App Store provisioning profile for com.pablo.rackoff
#     saved as RackOff_MAS.provisionprofile in this directory
# ===================================================================

set -euo pipefail

APP_NAME="RackOff"
BUNDLE_ID="com.pablo.rackoff"
TEAM_ID="V433H655PN"
APP_BUNDLE="${APP_NAME}.app"
PROVISION_PROFILE="RackOff_MAS.provisionprofile"
PKG_PATH="dist/${APP_NAME}-mas.pkg"

APP_SIGN_IDENTITY="Apple Distribution: Pablo Alvarado (${TEAM_ID})"
INSTALLER_SIGN_IDENTITY="3rd Party Mac Developer Installer: Pablo Alvarado (${TEAM_ID})"

if ! security find-identity -v -p codesigning | grep -q "Apple Distribution"; then
    echo "❌ No Apple Distribution certificate in the keychain."
    echo "   Create one at developer.apple.com (Certificates → Apple Distribution)"
    echo "   or via Xcode → Settings → Accounts → Manage Certificates."
    exit 1
fi

if [[ ! -f "$PROVISION_PROFILE" ]]; then
    echo "❌ Missing provisioning profile: ${PROVISION_PROFILE}"
    echo "   Download an App Store provisioning profile for ${BUNDLE_ID}"
    echo "   from developer.apple.com and save it here as ${PROVISION_PROFILE}."
    exit 1
fi

echo "📦 Building app via build.sh..."
./build.sh

echo "📜 Embedding provisioning profile..."
cp "$PROVISION_PROFILE" "${APP_BUNDLE}/Contents/embedded.provisionprofile"

# MAS entitlements. Note: the desktop/documents ".read-write" keys in
# RackOff.entitlements are NOT real sandbox entitlements — sandboxed access
# to those folders goes through NSOpenPanel + security-scoped bookmarks,
# which VacManager already implements. bookmarks.app-scope makes the saved
# bookmarks survive relaunch. application-identifier/team-identifier are
# required for App Store validation on hand-rolled (non-Xcode) builds.
MERGED_ENTITLEMENTS="$(mktemp -t rackoff-mas-entitlements).plist"
cat > "$MERGED_ENTITLEMENTS" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
    <key>com.apple.security.files.bookmarks.app-scope</key>
    <true/>
    <key>com.apple.application-identifier</key>
    <string>${TEAM_ID}.${BUNDLE_ID}</string>
    <key>com.apple.developer.team-identifier</key>
    <string>${TEAM_ID}</string>
</dict>
</plist>
EOF

echo "🔏 Re-signing for Mac App Store with: ${APP_SIGN_IDENTITY}"
codesign --force --timestamp \
    --entitlements "$MERGED_ENTITLEMENTS" \
    --sign "$APP_SIGN_IDENTITY" \
    "$APP_BUNDLE"
codesign --verify --verbose "$APP_BUNDLE"
rm -f "$MERGED_ENTITLEMENTS"

echo "📦 Building installer package..."
mkdir -p dist
productbuild --component "$APP_BUNDLE" /Applications \
    --sign "$INSTALLER_SIGN_IDENTITY" \
    "$PKG_PATH"

echo "✨ MAS build complete: ${PKG_PATH}"
echo "👉 Upload with Transporter.app (drag the .pkg in)."
