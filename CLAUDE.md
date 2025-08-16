# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 🎯 Project Overview

RackOff is a minimal macOS menu bar app that archives desktop clutter into organized daily folders. It's part of the SoftStack suite - modular apps that do one thing perfectly.

## 🛠 Build & Development Commands

```bash
# Build the app
./build.sh

# Run the built app
open RackOff.app

# Install to Applications
cp -r RackOff.app /Applications/

# Clean build artifacts
rm -rf RackOff.app

# Debug compilation issues
swiftc -version  # Check Swift compiler version
```

## 🏗 Architecture & Key Components

### Core Structure
- **SwiftUI menu bar app** with popover interface
- **No Package.swift** - uses direct swiftc compilation via build.sh
- **Target**: arm64-apple-macos12.0 (Apple Silicon native)
- **LSUIElement**: true (runs as menu bar only, no dock icon)

### Key Files & Their Roles

1. **RackOffApp.swift**: Entry point, manages NSStatusItem and popover
   - Creates menu bar sparkles icon
   - Handles popover show/hide logic

2. **ContentView.swift**: Main UI with RackOff branding
   - Gradient title with playful aesthetics
   - Color-coded file type toggles
   - Animated "Clean Now" button with hover effects

3. **VacManager.swift**: Business logic and file operations
   - Manages file type configurations
   - Performs vacuum operations (moving files to dated archives)
   - Handles UserDefaults persistence
   - Creates archive structure: `Archive/YYYY-MM-DD/`

### Data Flow
```
User Toggle → VacManager.toggleFileType() → UserDefaults save
Clean Now → VacManager.vacuum() → FileManager operations → Notification
```

## 📝 Code Style Conventions

- **SwiftUI views**: Extensive use of modifiers for visual polish
- **Animations**: Spring animations with specific response/damping values
- **Colors**: Inline LinearGradients for branded look (orange-pink theme)
- **State management**: @StateObject for VacManager, @State for UI states
- **File operations**: Async/await pattern for vacuum operations

## 🎨 UI Design Language

- **Branding**: "RackOff" with sparkles icon and gradient text
- **Color scheme**: Orange-pink gradients throughout
- **Interactions**: Hover effects with scale, glow, and rotation animations
- **File types**: Each has unique accent color (Screenshots=orange, PDFs=blue, etc.)
- **Button states**: Visual feedback for hover, active, and processing states

## 🔧 Development Notes

- **No external dependencies** - pure SwiftUI/AppKit
- **UserDefaults keys**: schedule, sourceFolder, destinationFolder, lastRun, fileType_*
- **Notification system**: Uses deprecated NSUserNotification (consider updating to UNUserNotificationCenter)
- **File patterns**: Special handling for screenshots vs general extensions
- **Schedule options**: Manual, On Launch, Daily (though daily scheduling not fully implemented)
- **Menu bar interaction**: Left-click shows popover, right-click shows context menu with About/Quit
- **Popover behavior**: Transient (auto-closes when clicking outside)

## ⚠️ Known Limitations & Migration Notes

- **Daily scheduling mentioned in UI but not implemented** with actual timer/scheduler
- **NSUserNotification is deprecated** (works but should migrate to UNUserNotificationCenter)
- **Only targets ARM64** (no Intel support in current build config)
- **No app icon defined** beyond system symbol
- **Legacy artifacts**: DeskVac.app directory exists from previous branding (can be removed)
- **README out of sync**: Still references "DeskVac" instead of "RackOff"

## 🚨 Important Rebrand Context

This app was recently rebranded from "DeskVac" to "RackOff". While the Swift code has been updated, some artifacts remain:
- Old DeskVac.app build in the directory
- README.md still uses DeskVac branding and references
- Build script and code are fully updated to RackOff