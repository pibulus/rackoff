# CLAUDE.md

Hey Claude Code, here's the deal with RackOff.

## What this is

RackOff - a menu bar app that cleans desktops without being annoying about it.

Built with SwiftUI because we like things simple. Does one thing. Does it well.  
Honestly, it's just three Swift files and some attitude.

## Building and running

```bash
./build.sh              # Compiles and signs everything
open RackOff.app        # Test it out
cp -r RackOff.app /Applications/  # Ship it to the world (or just yourself)
```

## The architecture (if you can call it that)

**Three files, no drama:**
- `RackOffApp.swift` - Menu bar magic, icon switching, the sparkles
- `ContentView.swift` - That pretty popover with gradients
- `VacManager.swift` - The actual cleaning brain

**How it all works:**
- SwiftUI + AppKit for menu bar stuff (because that's how you do it)
- UserDefaults for remembering what you like
- Timer for the daily 9 AM cleaning (if you're into that)
- FileManager for moving files around (safely, always safely)

## Current state

✅ **What's working great:**
- App Store ready (sandboxed, entitled, the whole deal)
- No deprecated APIs haunting us
- Memory-safe (we checked, no leaks)
- Builds clean, runs smooth

⚠️ **What it still needs:**
- A real app icon (sparkles emoji doesn't count for App Store)
- Your Developer ID for proper signing
- Screenshots for the App Store listing
- Maybe a website? (kidding, maybe not)

## Technical choices explained

**Why compile directly instead of Xcode?**
Because Xcode projects are where simplicity goes to die. Our build script is 100 lines.  
Xcode would generate 1000 lines of XML we'd never look at.

**Why track the .app bundle?**
So you can grab and test immediately. See exactly what ships.  
No "works on my machine" mysteries.

**Why these three organization modes?**
- Quick Archive: for the "just clean it" folks
- Sort by Type: for the organizers
- Smart Clean: for the control enthusiasts

Each mode took like 20 lines of code. Why not?

## The limits (keeping it real)

- ARM64 only (Intel Macs, we hardly knew ye)
- Desktop/Documents/Downloads only (sandbox rules)
- 9 AM schedule isn't configurable (yet - but honestly, is 9 AM not perfect?)
- No Windows version (obviously)

## Writing style notes

Keep it human. We're not robots talking to robots.

Short sentences work. But sometimes you need a longer one to explain something properly, and that's totally fine.

Show personality but don't force it. If a feature is boring, let it be boring.  
The cleaning happens. Files move. Desktop's clean. Sometimes that's enough.

## Debugging tips

If something breaks, check:
1. Sandbox entitlements (did we lose file access?)
2. Timer scheduling (is the Timer getting deallocated?)
3. Force unwrapping (we removed most, but check anyway)

The app is pretty bulletproof now, but desktops are chaos. Expect chaos.

---

That's RackOff. Desktop cleaning that doesn't overthink it.

Hit me up if something's confusing. Otherwise, happy coding.