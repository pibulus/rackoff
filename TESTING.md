# RackOff Testing

Use this before testing against a real Desktop.

## Automated Smoke Test

```bash
./scripts/smoke-test.sh
```

The smoke test creates a temporary fake Desktop and Archive folder. It checks:

- screenshot detection for `Screenshot ... .png`
- CleanShot screenshot detection
- document, media, and archive matching
- hidden file and folder skipping
- Quick Archive date folders based on creation date
- Sort by Type folders
- Smart Clean `Skip`
- undo restore behavior

It does not touch `~/Desktop` or `~/Documents/Archive`.

## Compile Check

```bash
swiftc RackOffApp.swift ContentView.swift VacManager.swift PreferencesView.swift RackOffConstants.swift \
  -target arm64-apple-macos12.0 \
  -framework SwiftUI \
  -framework AppKit \
  -framework UserNotifications \
  -parse-as-library \
  -typecheck
```

## Manual Real-Desktop Test

Only do this when you are ready for RackOff to move real files.

1. Build the app:

```bash
./build.sh
```

2. Open it:

```bash
open RackOff.app
```

3. Set the mode to `Quick`.

4. Start with screenshots only enabled.

5. Confirm the archive destination is the default `~/Documents/Archive`. Saved preferences can change this. The current Preferences UI also has a known display bug where it can show `~/Desktop/Archive` even though the actual default is `~/Documents/Archive`.

6. Click `Clean Now`.

7. Confirm screenshots moved to:

```text
~/Documents/Archive/YYYY-MM-DD/
```

8. Use `Undo Last Clean` from the right-click menu or Preferences footer and confirm the files return to Desktop.

## Organization Questions To Validate

- Are screenshots best grouped daily, weekly, or by project/source?
- Should documents default to off, or should PDFs be cleaned by default?
- Should CSV/JSON/XML/log files live under Archives, Documents, or Developer Files?
- Should media exclude all screenshot tools, including CleanShot and screen recordings?
- Should RackOff support multiple source folders before launch, or stay Desktop-only first?
