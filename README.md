# ✨ RackOff

A delightful macOS menu bar app that archives desktop clutter into organized folders with attitude. Your desktop's chaos nemesis.

## Features

- **🎯 Three Organization Modes**: Quick Archive, Sort by Type, Smart Clean
- **📦 Smart File Detection**: Screenshots, Documents, Media, Archives
- **📅 Flexible Archiving**: Daily/weekly/monthly folders or type-based organization
- **⏰ Scheduling Options**: Manual, on launch, or daily at 9 AM
- **🎨 Playful UI**: Gradient animations, hover effects, and personality
- **✨ Customizable Icons**: Choose your menu bar style
- **🔐 App Store Ready**: Sandboxed, code-signed, and optimized

## Building

```bash
./build.sh
```

## Installing

```bash
cp -r RackOff.app /Applications/
```

## Usage

1. Click the sparkles icon in your menu bar
2. Toggle which file types to rack off
3. Select source folder (default: Desktop)
4. Select destination folder (default: Documents/Archive)
5. Choose schedule (Manual/On Launch/Daily)
6. Click "Clean Now" to clean up

Files are organized into `Archive/YYYY-MM-DD/` folders.

## File Types

- **Screenshots** - screenshot*.jpg/png/jpeg files
- **PDFs** - All PDF documents
- **Images** - jpg, jpeg, png, gif, webp, heic
- **Downloads** - dmg, zip, pkg installers
- **Documents** - doc, docx, txt, rtf files

## One Thing Done Well

RackOff does ONE thing: it racks off your desktop mess into organized daily folders. That's it. That's the app.

---

Part of the SoftStack suite - $1 apps that do one thing perfectly.