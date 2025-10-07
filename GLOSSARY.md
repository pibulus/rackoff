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
`VacManager.swift` - File scanning, moving, undo, scheduling

**RackOffConstants** - App-wide constants
`RackOffConstants.swift` - Sizes, spacing, colors, animations

## Core Concepts

**Three Organization Modes**
- Quick Archive: Everything → date folders (YYYY-MM-DD)
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
