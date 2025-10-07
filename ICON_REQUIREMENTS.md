# 🎨 RackOff App Icon Requirements

## What You Need

RackOff currently uses SF Symbols (sparkles icon) in the menu bar, which works for local development but **won't pass App Store review**. You need a proper app icon.

## Icon Specifications

### Format
- **File Format**: `.icns` (Icon Set)
- **Source Format**: PNG with transparent background (1024x1024)
- **Color Profile**: sRGB recommended

### Required Sizes
The .icns file must contain all these resolutions:
- 16x16 (standard + @2x retina)
- 32x32 (standard + @2x retina)
- 128x128 (standard + @2x retina)
- 256x256 (standard + @2x retina)
- 512x512 (standard + @2x retina)

## Design Guidelines

### RackOff Brand Identity
- **Vibe**: Sparkles + clean desktop = tidy magic
- **Colors**: Orange/pink gradient (matches current gradient in UI)
  - Primary: `#FF9933` (orange)
  - Secondary: `#FF6699` (pink)
- **Style**: Pastel punk, friendly, a bit cheeky
- **Avoid**: Corporate, boring, generic folder icons

### Icon Ideas
1. **Sparkles + Desktop** - Literal sparkles cleaning a desktop surface
2. **Organized Grid** - Files transforming from chaos to grid
3. **Magic Broom** - Witch's broom with sparkle trail (playful)
4. **Vacuum Icon** - Abstract vacuum with pastel colors (matches "vac" theme)
5. **Tidy Spark** - Single sparkle with motion lines

### App Store Guidelines
- Must be recognizable at 16x16 (menu bar size)
- No transparency in outer shape (rounded square expected)
- Avoid text/words in the icon
- Should work in both light and dark mode menu bars

## Creation Process

### Method 1: Using a Design Tool

**Figma / Sketch / Illustrator:**
1. Create 1024x1024 artboard
2. Design icon with 8% padding around edges
3. Export as PNG at 1024x1024

**Convert to .icns:**
```bash
# Create iconset directory
mkdir RackOff.iconset

# Generate all sizes (using your 1024x1024 source)
sips -z 16 16     icon-1024.png --out RackOff.iconset/icon_16x16.png
sips -z 32 32     icon-1024.png --out RackOff.iconset/icon_16x16@2x.png
sips -z 32 32     icon-1024.png --out RackOff.iconset/icon_32x32.png
sips -z 64 64     icon-1024.png --out RackOff.iconset/icon_32x32@2x.png
sips -z 128 128   icon-1024.png --out RackOff.iconset/icon_128x128.png
sips -z 256 256   icon-1024.png --out RackOff.iconset/icon_128x128@2x.png
sips -z 256 256   icon-1024.png --out RackOff.iconset/icon_256x256.png
sips -z 512 512   icon-1024.png --out RackOff.iconset/icon_256x256@2x.png
sips -z 512 512   icon-1024.png --out RackOff.iconset/icon_512x512.png
sips -z 1024 1024 icon-1024.png --out RackOff.iconset/icon_512x512@2x.png

# Convert to .icns
iconutil -c icns RackOff.iconset

# Result: RackOff.icns
```

### Method 2: AI Generation

**Using DALL-E / Midjourney:**
```
Prompt: "App icon for macOS desktop cleaning app called RackOff.
Minimalist sparkles with orange to pink gradient. Flat design,
rounded square shape, pastel punk aesthetic. Clean and friendly."
```

**Using SF Symbols (temporary placeholder):**
- Can use `sparkles` SF Symbol rendered as bitmap for testing
- Won't pass App Store review but good for development

## Integration

### 1. Add icon to build script

Update `build.sh`:
```bash
# Copy icon to Resources (after line ~23)
cp RackOff.icns "$APP_NAME.app/Contents/Resources/"
```

### 2. Update Info.plist

The build script already generates Info.plist. Add this key:
```xml
<key>CFBundleIconFile</key>
<string>RackOff</string>
```

### 3. Rebuild and test
```bash
./build.sh
open RackOff.app
```

The icon should appear in:
- Finder (when viewing .app file)
- Dock (if LSUIElement is false)
- App Switcher (Cmd+Tab)
- About window

## Current Status

❌ **Missing**: Proper app icon
✅ **Working**: SF Symbols icon in menu bar (development only)

## Next Steps

1. **Design Icon** - Use Figma/Sketch or commission a designer
2. **Generate .icns** - Follow Method 1 above
3. **Update build.sh** - Add icon copy command
4. **Test build** - Verify icon appears in all contexts
5. **Commit** - Add RackOff.icns to git (exclude .iconset directory)

## Resources

- [Apple Icon Guidelines](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- [SF Symbols Browser](https://developer.apple.com/sf-symbols/) - For inspiration only
- [App Icon Generator](https://www.appicon.build/) - Online tool for .icns generation
- [Figma macOS Icon Template](https://www.figma.com/community/file/857303226040719059)

---

**Note**: The sparkles menu bar icon (current implementation) is fine for the menu bar display - that can stay as SF Symbols. This requirement is specifically for the **app bundle icon** that appears in Finder.
