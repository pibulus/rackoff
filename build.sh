#!/bin/bash

# ===================================================================
# DeskVac App Builder
# ===================================================================

APP_NAME="DeskVac"
BUNDLE_ID="com.pablo.deskvac"
VERSION="1.0"

echo "🛠 Building $APP_NAME..."

# Create app bundle structure
mkdir -p "$APP_NAME.app/Contents/MacOS"
mkdir -p "$APP_NAME.app/Contents/Resources"

# Compile Swift files
swiftc DeskVacApp.swift ContentView.swift VacManager.swift \
    -o "$APP_NAME.app/Contents/MacOS/$APP_NAME" \
    -target arm64-apple-macos12.0 \
    -framework SwiftUI \
    -framework AppKit \
    -parse-as-library

# Create Info.plist
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
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Create a simple icon (you can replace with actual icon later)
echo "📦 App bundle created: $APP_NAME.app"
echo "✨ Build complete!"
echo ""
echo "To run: open $APP_NAME.app"
echo "To install: cp -r $APP_NAME.app /Applications/"