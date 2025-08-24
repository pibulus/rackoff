# CLAUDE.md

Quick guidance for Claude Code when working on RackOff.

## What this is

RackOff - desktop cleaning with attitude.  
SwiftUI menu bar app. No nonsense. Does one thing well.

## Build commands

```bash
./build.sh              # Compile and sign
open RackOff.app        # Test it
cp -r RackOff.app /Applications/  # Ship it
```

## Architecture

**Three files. That's it:**
- `RackOffApp.swift` - Menu bar setup, icon management
- `ContentView.swift` - The UI you see in the popover
- `VacManager.swift` - The cleaning logic

**Key patterns:**
- SwiftUI + AppKit for menu bar
- UserDefaults for preferences
- Timer for daily scheduling
- FileManager for the actual cleaning

## Current state

✅ App Store ready:
- Sandboxed with proper entitlements
- Modern APIs (no deprecations)
- Memory-safe (no leaks)
- Signed and optimized

⚠️ Needs before App Store:
- Real app icon (not just system symbol)
- Your Developer ID for signing
- Screenshots for listing

## Tech choices

**Why direct compilation?**
- No Xcode project bloat
- Clean, minimal build
- Fast iteration

**Why track the .app?**
- Easy testing for you
- Quick distribution
- See exactly what ships

## Organization modes

1. **Quick Archive** - Everything → daily folders
2. **Sort by Type** - Files → type folders
3. **Smart Clean** - Right-click to customize per type

## Known limits

- ARM64 only (no Intel Macs)
- Desktop/Documents/Downloads access only (sandboxed)
- 9 AM daily schedule (not configurable yet)

## Voice notes

Keep it minimal. No corporate speak.  
Short sentences. Clear actions.  
Show the door, get out of the way.

---

This is RackOff. Desktop cleaning that respects your space.