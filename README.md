# 🧹 DeskVac

A minimal macOS menu bar app that vacuums up desktop clutter into organized daily archives.

## Features

- **📦 Smart File Organization** - Archive files by type into dated folders
- **🎯 Modular Selection** - Choose what to vacuum: Screenshots, PDFs, Images, Downloads, Documents
- **📁 Custom Locations** - Pick source and destination folders
- **⏰ Flexible Scheduling** - Manual, on launch, or daily operation
- **🎨 Clean UI** - Simple menu bar app with SwiftUI interface

## Building

```bash
./build.sh
```

## Installing

```bash
cp -r DeskVac.app /Applications/
```

## Usage

1. Click the archive box icon in your menu bar
2. Toggle which file types to vacuum
3. Select source folder (default: Desktop)
4. Select destination folder (default: Documents/Archive)
5. Choose schedule (Manual/On Launch/Daily)
6. Click "Vacuum Now" to clean up

Files are organized into `Archive/YYYY-MM-DD/` folders.

## File Types

- **Screenshots** - screenshot*.jpg/png/jpeg files
- **PDFs** - All PDF documents
- **Images** - jpg, jpeg, png, gif, webp, heic
- **Downloads** - dmg, zip, pkg installers
- **Documents** - doc, docx, txt, rtf files

## One Thing Done Well

DeskVac does ONE thing: it vacuums your desktop mess into organized daily folders. That's it. That's the app.

---

Part of the SoftStack suite - $1 apps that do one thing perfectly.