#!/bin/bash

# ===================================================================
# RackOff App Builder - App Store Ready
# ===================================================================

APP_NAME="RackOff"
BUNDLE_ID="com.pablo.rackoff"
VERSION="1.0"
BUILD_NUMBER="1"

# Code signing identity (use "-" for ad-hoc signing during development)
# For App Store: Replace with your Developer ID
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
    -target arm64-apple-macos12.0 \
    -framework SwiftUI \
    -framework AppKit \
    -framework UserNotifications \
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
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2024 Pablo. All rights reserved.</string>
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
</dict>
</plist>
EOF

# Copy entitlements file
if [ -f "RackOff.entitlements" ]; then
    cp RackOff.entitlements "$APP_NAME.app/Contents/"
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
echo "📱 For App Store submission:"
echo "1. Replace CODESIGN_IDENTITY with your Developer ID"
echo "2. Build with: ./build.sh"
echo "3. Create archive with: xcrun altool or Xcode"