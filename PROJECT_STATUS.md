# RackOff Project Status

Last updated: 2026-05-14

## Current Focus

RackOff is back in product/test mode. App Store submission work is parked until the cleaner behavior, preferences UI, docs, and repo organization are trustworthy.

Priority order:
1. Prove the cleaner safely handles screenshots, documents, media, and archives.
2. Decide whether the current organization model is the right default for real messy desktops.
3. Make Preferences honest: either wire controls to behavior or remove controls that are only visual.
4. Refresh GitHub/repo housekeeping.
5. Return to icon, signing, screenshots, and App Store Connect.

## GitHub State

- Repo: `pibulus/rackoff`
- Default branch: `main`
- Local `main`: clean and aligned with `origin/main`
- Open PRs: none
- Open issues: none
- Old merged local branches still exist:
  - `app-store-optimization`
  - `feat/undo-and-customization`
  - `fix/menu-and-minimal-ui`
- Old stash exists: `stash@{0}` named `Debug changes for screenshot detection issue`
  - It contains debug logging plus an older version of creation-date archive behavior.
  - The useful creation-date behavior is already on `main`.
  - Do not drop it until Pablo explicitly decides the old debug stash is no longer needed.

## Current Product Behavior

- Default source folder: `~/Desktop`
- Default archive folder: `~/Documents/Archive`
- Default enabled type: Screenshots
- Other available types: Documents, Media, Archives
- Quick Archive: enabled files go into `YYYY-MM-DD` folders based on file creation date.
- Sort by Type: enabled files go into type folders.
- Smart Clean: each enabled file type can use daily, weekly, monthly, type, custom, or skip behavior.
- Undo works for the last cleaning operation in the current app session.

## Known Gaps

- Preferences contains controls that are not fully wired to `VacManager`.
- Schedule UI uses local state and does not yet reliably update the saved schedule.
- Folder toggles for Downloads/Documents are presentational; the cleaner currently uses one source folder.
- Stats in Preferences are hardcoded.
- App icon and production signing are still missing, but they are not the immediate focus.

## Verification Commands

```bash
swiftc RackOffApp.swift ContentView.swift VacManager.swift PreferencesView.swift RackOffConstants.swift \
  -target arm64-apple-macos12.0 \
  -framework SwiftUI \
  -framework AppKit \
  -framework UserNotifications \
  -parse-as-library \
  -typecheck

./scripts/smoke-test.sh
```
