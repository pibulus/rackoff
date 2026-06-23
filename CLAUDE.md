# CLAUDE.md

Hey Claude Code, here's the deal with RackOff.

## What this is

RackOff - a menu bar app that cleans desktops without being annoying about it.

Built with SwiftUI because we like things simple. Does one thing. Does it well.
The app started tiny, but it is now a small direct-built macOS app with a real preferences surface, constants, docs, and smoke tests.

## Building and running

```bash
./build.sh              # Compiles and signs everything
./scripts/smoke-test.sh # Tests cleaner behavior in temp folders
open RackOff.app        # Test it out
cp -r RackOff.app /Applications/  # Ship it to the world (or just yourself)
```

## The architecture (if you can call it that)

**Main files:**
- `RackOffApp.swift` - Menu bar magic, icon switching, the sparkles
- `ContentView.swift` - That pretty popover with gradients
- `VacManager.swift` - The actual cleaning brain
- `PreferencesView.swift` - Preferences window and settings UI
- `RackOffConstants.swift` - Shared colors, spacing, sizing, and animation constants

**How it all works:**
- SwiftUI + AppKit for menu bar stuff (because that's how you do it)
- UserDefaults for remembering what you like
- Timer for the daily 9 AM cleaning (if you're into that)
- FileManager for moving files around (safely, always safely)

## Current state

✅ **What's working great:**
- App Store compliant (sandboxed, entitled, privacy manifest, usage descriptions)
- No deprecated APIs haunting us
- Memory-safe (we checked, no leaks)
- Builds clean, runs smooth
- Security-scoped bookmarks for real folder access
- Comprehensive sandbox protection with recovery tools
- Smoke test covers the core cleaner paths without touching the real Desktop

🎯 **Current focus:**
- Prove the app handles real screenshot-heavy desktops safely
- Decide whether daily/type/smart organization is the right default model
- Wire or simplify Preferences so it only shows real behavior
- Keep App Store work parked until the product/test pass is done

⚠️ **What it needs for submission:**
- App icon (.icns file) - see ICON_REQUIREMENTS.md
- Apple/Mac App Distribution signing - need Apple Developer membership
- App Store Connect listing - see APP_STORE_CHECKLIST.md

📚 **Docs added:**
- `APP_STORE_CHECKLIST.md` - Complete submission guide
- `ICON_REQUIREMENTS.md` - Icon creation workflow
- `APP_STORE_STATUS.md` - Current readiness tracker (40%)
- `RECOVERY_GUIDE.md` - Sandbox file recovery instructions
- `PrivacyInfo.xcprivacy` - 2025 privacy manifest
- `PROJECT_STATUS.md` - Current repo/product state
- `TESTING.md` - Safe automated and manual test workflow

## Technical choices explained

**Why compile directly instead of Xcode?**
Because Xcode projects are where simplicity goes to die. Our build script is readable and direct.
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
- Daily/on-launch scheduling is wired and tested. Daily survives sleep via a catch-up check (on launch + on wake) that uses `lastRun`, since a bare 24h Timer can't be trusted on a laptop. There's no launch-at-login item, so "daily" is honest only within the app's running lifetime — it cleans the first time you're awake past the scheduled time, not while the app is closed.
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
