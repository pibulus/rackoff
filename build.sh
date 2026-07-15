#!/bin/bash
set -euo pipefail

# ===================================================================
# RackOff App Builder
# ===================================================================

APP_NAME="RackOff"
BUNDLE_ID="com.pablo.rackoff"
VERSION="1.0"
BUILD_NUMBER="1"

# Code signing identity (use "-" for ad-hoc signing during development).
# For Mac App Store distribution, use Apple Distribution or Mac App Distribution.
# Developer ID is for direct distribution outside the Mac App Store.
CODESIGN_IDENTITY="-"

echo "🛠 Building $APP_NAME..."

# Clean previous build
rm -rf "$APP_NAME.app"

# Create app bundle structure
mkdir -p "$APP_NAME.app/Contents/MacOS"
mkdir -p "$APP_NAME.app/Contents/Resources"

# Compile Swift files with optimizations
swiftc RackOffApp.swift ContentView.swift VacManager.swift PreferencesView.swift RackOffConstants.swift \
    -o "$APP_NAME.app/Contents/MacOS/$APP_NAME" \
    -target arm64-apple-macos13.0 \
    -framework SwiftUI \
    -framework AppKit \
    -framework UserNotifications \
    -framework ServiceManagement \
    -parse-as-library \
    -O \
    -whole-module-optimization \
    -enable-library-evolution

# Create Info.plist with App Store required keys
cat > "$APP_NAME.app/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>RackOff - Desktop Cleaner</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>CFBundleIconFile</key>
    <string>RackOff</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2025 Pablo. All rights reserved.</string>
    <key>CFBundleDocumentTypes</key>
    <array/>
    <key>NSAppleScriptEnabled</key>
    <false/>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>MacOSX</string>
    </array>
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
    <key>NSDesktopFolderUsageDescription</key>
    <string>RackOff organizes files from your Desktop into the Archive folder.</string>
    <key>NSDocumentsFolderUsageDescription</key>
    <string>RackOff stores organized files in your Documents/Archive folder.</string>
    <key>NSDownloadsFolderUsageDescription</key>
    <string>RackOff can optionally organize files from your Downloads folder.</string>
</dict>
</plist>
EOF

# Copy entitlements file
if [ -f "RackOff.entitlements" ]; then
    cp RackOff.entitlements "$APP_NAME.app/Contents/"
fi

# Copy privacy manifest
if [ -f "PrivacyInfo.xcprivacy" ]; then
    cp PrivacyInfo.xcprivacy "$APP_NAME.app/Contents/Resources/"
fi

# Copy app icon if present
if [ -f "RackOff.icns" ]; then
    cp RackOff.icns "$APP_NAME.app/Contents/Resources/"
    echo "✨ App icon added"
else
    echo "⚠️  No app icon found (RackOff.icns) - required for App Store"
fi

# Code sign the app
echo "🔐 Code signing..."
codesign --force --deep --sign "$CODESIGN_IDENTITY" \
    --entitlements RackOff.entitlements \
    --options runtime \
    "$APP_NAME.app"

# Verify code signing
echo "✅ Verifying signature..."
codesign --verify --verbose "$APP_NAME.app"

echo "📦 App bundle created: $APP_NAME.app"
echo "✨ Build complete!"
echo ""
echo "To run: open $APP_NAME.app"
echo "To install: cp -r $APP_NAME.app /Applications/"
echo ""
echo "📱 Distribution Readiness:"
echo "✅ Sandboxed with entitlements"
echo "✅ Privacy manifest included"
echo "✅ Usage descriptions added"
if [ -f "RackOff.icns" ]; then
    echo "✅ App icon included"
else
    echo "❌ Missing app icon (see ICON_REQUIREMENTS.md)"
fi
echo ""
echo "Next steps before distribution:"
echo "1. Keep testing behavior → See TESTING.md"
echo "2. Create app icon → See ICON_REQUIREMENTS.md"
echo "3. Replace CODESIGN_IDENTITY with the right distribution certificate"
echo "4. Build with: ./build.sh"
echo "5. For direct distribution, notarize with: xcrun notarytool submit"
echo "6. For Mac App Store, upload through Xcode or App Store Connect"
echo ""
echo "See APP_STORE_CHECKLIST.md for complete submission guide"
