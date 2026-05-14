# RackOff - Code Glossary

Quick reference for RackOff's desktop cleaning architecture.

## Views (SwiftUI)

**ContentView** - Main popover UI with clean button
`ContentView.swift` - File types, organization modes, vacuum action

**FileTypeRow** - Individual file type toggle row
`ContentView.swift` - Toggle, icon, destination info

**OrganizationButton** - Mode selector (Quick/Sort/Smart)
`ContentView.swift` - Quick Archive, Sort by Type, Smart Clean

**PreferencesView** - Settings window
`PreferencesView.swift` - Schedule, folders, file type config

**RackOffApp** - Main app entry
`RackOffApp.swift` - MenuBar setup, AppDelegate

## Models & Enums

**FileType** - File category definition
`VacManager.swift` - Name, extensions, icon, matcher, destination

**Schedule** - Cleaning schedule options
`VacManager.swift` - Manual, On Launch, Daily (9 AM)

**OrganizationMode** - Cleaning organization strategy
`VacManager.swift` - Quick Archive, Sort by Type, Smart Clean

**FileDestination** - Where files go in Smart Clean mode
`VacManager.swift` - Daily, Weekly, Monthly, Type Folder, Custom, Skip

**FileMatcher** - How to identify files
`VacManager.swift` - byExtension, byFilenamePattern, byExtensionExcludingPattern

**UndoOperation** - Track file moves for undo
`VacManager.swift` - Source, destination, timestamp

## Services & Managers

**VacManager** - Core cleaning logic (@MainActor)
`VacManager.swift` - File scanning, matching, moving, undo, scheduling, sandbox bookmarks

**RackOffConstants** - App-wide constants
`RackOffConstants.swift` - Sizes, spacing, colors, animations

## Core Concepts

**Three Organization Modes**
- Quick Archive: Enabled files → date folders (YYYY-MM-DD, based on creation date)
- Sort by Type: Everything → type folders (Screenshots/, Documents/)
- Smart Clean: Per-type destinations (Daily/Weekly/Monthly/Type/Custom)

**File Type Matchers**
- Screenshots: byFilenamePattern (contains "Screenshot", "CleanShot", etc.)
- Documents: byExtension (.pdf, .doc, .docx, etc.)
- Media: byExtensionExcludingPattern (images/video EXCEPT screenshots)
- Archives: byExtension (.zip, .dmg, .pkg, .csv, etc.)

**Sandbox Security**
- Uses security-scoped bookmarks for Desktop/Documents access
- Stores bookmarks in UserDefaults
- Re-requests access if bookmarks are stale

**Undo System**
- Tracks all file moves in current session
- One-time undo restores all files
- Clears after successful undo

**Daily Scheduling**
- Timer-based execution at configured time (default 9 AM)
- Reschedules for next day after trigger
- Persists timer state across app restarts
- Preferences schedule controls still need a wiring pass before relying on this for release

**Smoke Test Harness**
- `Tests/RackOffSmokeTest.swift` creates fake Desktop/Archive folders
- `scripts/smoke-test.sh` compiles and runs the harness
- Covers Quick Archive, Sort by Type, Smart Clean Skip, screenshot matching, hidden file skipping, and undo

## Documentation Files

**APP_STORE_CHECKLIST.md** - Complete App Store submission guide
- Prerequisites (Developer account, certificates)
- Code compliance checklist
- Build & sign instructions
- Notarization process
- Asset requirements (screenshots, icon, marketing copy)
- Submission workflow

**ICON_REQUIREMENTS.md** - App icon creation guide
- Design specifications (.icns format, sizes)
- Brand guidelines (colors, style)
- Creation workflow (Figma → PNG → .icns)
- Integration instructions

**APP_STORE_STATUS.md** - Current readiness tracker
- Completed features (code compliance, docs)
- Blockers (icon, signing, listing)
- Timeline estimates

**PROJECT_STATUS.md** - Current active project state
- Product/test focus
- GitHub state and old branch/stash notes
- Known product gaps

**TESTING.md** - Verification guide
- Compile check
- Automated smoke test
- Manual real-Desktop test checklist

**RECOVERY_GUIDE.md** - Sandbox file recovery
- Where files went (sandbox container path)
- Recovery script usage
- Manual recovery options
- What was fixed

**PrivacyInfo.xcprivacy** - Privacy manifest (2025 requirement)
- File timestamp API usage declaration
- Disk space API usage declaration
- No data collection statement
