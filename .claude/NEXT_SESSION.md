# NEXT SESSION — App Store Launch Prep

## Status (where we left off)

- ✅ Direct distribution SHIPPED — signed, notarized, DMG on rackoff.app
- ⏳ Xcode downloading (you clicked Install in App Store)
- ❌ Apple Distribution cert — needs Xcode installed, then 2 clicks
- ❌ App Store Connect listing — not started

## Once Xcode finishes installing

1. Open Xcode → Settings (⌘,) → Accounts
2. Your Apple ID should be listed (pibulus@gmail.com)
3. Click "Manage Certificates..." → "+" → "Apple Distribution"
4. Done. Xcode handles the keychain pairing automatically.
5. Then I'll update build.sh and we upload to App Store Connect.

## What's needed for App Store Connect

### Required:
- App description (draft below)
- 3-5 screenshots at 2560x1600 (take these with the app running)
- Keywords (100 chars max)
- Privacy policy URL: https://rackoff.app/privacy (already live)
- Support URL
- Category: Utilities
- Age rating: 4+

### Screenshot shots to grab:
1. Popover open showing file types + "Clean Now" button
2. Preferences → Folders tab showing Organization Style cards
3. Preferences → Schedule tab showing Daily + stats
4. Success banner after a clean ("Swept 5 files!")
5. Menu bar icon in context (or just the icon itself)

## App Store copy (draft)

### Name: RackOff
### Subtitle: Desktop cleaning that gets it

### Description:
```
Your desktop's chaos nemesis. Finally.

RackOff sweeps your desktop clutter into organized folders with one click. No accounts. No cloud. No drama.

WHAT IT DOES
• Screenshots from your 3pm debugging spiral? Gone.
• PDFs that appeared from nowhere? Tidied.
• Files that were "just temporary" two weeks ago? Stashed.

HOW IT WORKS
Choose what bugs you — screenshots, documents, media, archives — and RackOff moves it to your Stash folder. Two organization styles: Date Folders (2026/07-July) or Category Folders (Screenshots, Documents, etc.). Files are never deleted, just relocated.

RIGHT-CLICK MAGIC
• Undo your last clean
• Launch at login
• Pick your menu bar icon
• Open your Stash in Finder

BUILT RIGHT
• Sandboxed and notarized
• No data collection ever
• Runs locally on your Mac
• Privacy-first by design

Made with attitude in Bangkok. Part of SoftStack.
```

### Keywords: desktop,cleaner,organizer,files,screenshots,tidy,workspace,utility,productivity,declutter

### Review notes:
```
RackOff is a menu bar app. It has no window on launch — click
the broom icon in the menu bar to open the popover.

Testing:
1. Click the menu bar icon to open the popover
2. Toggle Screenshots ON (should be on by default)
3. Place a test file on Desktop
4. Click "Clean Now"
5. File moves to ~/Documents/Stash/
6. Right-click menu bar icon → Undo Last Clean to restore

File access: The app uses standard macOS sandbox file access
with explicit user-facing usage descriptions.
```

## Commands for next session

```bash
# Build for App Store (once cert is set up):
# CODESIGN_IDENTITY="Apple Distribution: Pablo Alvarado (V433H655PN)" ./build.sh

# Upload to App Store Connect:
# xcrun altool --upload-app -f RackOff.app -t macos \
#   -u pibulus@gmail.com -p "@keychain:AC_PASSWORD" --team-id V433H655PN
```
