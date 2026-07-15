# RackOff Project Status

Last updated: 2026-07-15

## Current Focus

RackOff is in **dogfooding mode**. Installed in /Applications, ready for daily use.
App Store submission work is parked — the priority is real-world usage and finding rough edges.

## What's Working

- Quick Archive mode: enabled file types → `YYYY-MM-DD` date folders based on file creation date
- File types: Screenshots (on by default), Documents, Media, Archives (off by default)
- Peek strip: recently-racked files visible, with empty-state hint
- Undo: restores all files from last clean, current session only
- Stats: lifetime files/bytes/sessions tracked and persisted
- Schedule: Daily (with configurable time) or On Launch, properly wired
- Archive destination: changeable via Preferences folder picker
- Launch at Login: right-click menu bar → toggle (uses SMAppService)
- App icon: sparkle gradient (orange→pink), integrated into bundle
- Menu bar: sparkles/circle/dot icon style, right-click context menu
- DMG installer: `./create-dmg.sh` creates drag-to-install DMG

## GitHub State

- Repo: `pibulus/rackoff`
- Default branch: `main`
- Old stash exists: `stash@{0}` named `Debug changes for screenshot detection issue`
  - Do not drop until Pablo explicitly decides it's no longer needed.

## Known Gaps

- Source folders: Desktop only. Downloads/Documents shown as "Coming Soon" in Preferences.
- Organization mode: locked to Quick Archive. Sort by Type and Smart Clean engines exist in VacManager but have no UI.
- Custom folder picker for Smart Clean per-file-type destinations: engine exists, no UI.
- Code signing: ad-hoc (`-`), fine for personal use. Real Developer ID needed for distribution.
- Universal binary: ARM64 only. Intel Macs would need x86_64 + lipo.

## Verification Commands

```bash
# Type-check only (fast)
swiftc RackOffApp.swift ContentView.swift VacManager.swift PreferencesView.swift RackOffConstants.swift \
  -target arm64-apple-macos13.0 \
  -framework SwiftUI \
  -framework AppKit \
  -framework UserNotifications \
  -framework ServiceManagement \
  -parse-as-library \
  -typecheck

# Smoke test
./scripts/smoke-test.sh

# Build app
./build.sh

# Create DMG
./create-dmg.sh

# Install
cp -r RackOff.app /Applications/
```
