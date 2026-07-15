import Foundation
import SwiftUI
import UserNotifications

/// The name of the folder RackOff tidies into, under ~/Documents.
/// "Stash" over "Archive" on purpose: it says *kept safe*, not *thrown away* —
/// the trust message that makes a messy person clean a second time. It's also a
/// place you'd actually open and browse, not a graveyard.
let rackOffFolderName = "Stash"

enum Schedule: String, CaseIterable, Codable {
    case manual = "Manual"
    case onLaunch = "On Launch"
    case daily = "Daily"
}

enum OrganizationMode: String, CaseIterable, Codable {
    case quickArchive = "Quick Archive"
    case sortByType = "Sort by Type"
    case smartClean = "Smart Clean"
}

enum FileDestination: String, CaseIterable, Codable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case typeFolder = "Type Folder"
    case custom = "Custom Folder"
    case skip = "Skip"
}

struct FileType: Identifiable, Codable {
    var id = UUID()
    let name: String
    var extensions: [String]
    let icon: String
    var isEnabled: Bool
    var destination: FileDestination
    var customDestination: URL?
    var matcher: FileMatcher
    
    init(name: String, extensions: [String], icon: String, isEnabled: Bool = false, destination: FileDestination = .daily, customDestination: URL? = nil, matcher: FileMatcher = .byExtension) {
        self.name = name
        self.extensions = extensions
        self.icon = icon
        self.isEnabled = isEnabled
        self.destination = destination
        self.customDestination = customDestination
        self.matcher = matcher
    }
}

enum FileMatcher: String, Codable {
    case byExtension = "extension"
    case byFilenamePattern = "pattern"
    case byExtensionExcludingPattern = "extension_excluding"
}

struct UndoOperation {
    let source: URL
    let destination: URL
    let timestamp: Date
}

/// A single file that RackOff has tidied away, kept so the user can still
/// see — and get back to — their recent stuff. This is the "Peek" carpet bag:
/// the desktop looks empty, but the last little while of your life is one click away.
struct RackedItem: Identifiable, Codable {
    var id = UUID()
    let name: String
    let icon: String
    let accentName: String      // file-type name, drives the dot colour
    let destination: URL        // where it lives now (reveal-in-Finder target)
    let date: Date              // the file's own creation date (its place in the diary)

    enum CodingKeys: String, CodingKey {
        case id, name, icon, accentName, destination, date
    }
}

@MainActor
class VacManager: ObservableObject {
    // MARK: - Published Properties
    @Published var fileTypes: [FileType] = [
        FileType(
            name: "Screenshots",
            extensions: [".jpg", ".png", ".jpeg"],
            icon: "camera.viewfinder",
            isEnabled: true,
            destination: .daily,
            matcher: .byFilenamePattern
        ),
        FileType(
            name: "Documents",
            extensions: [".pdf", ".doc", ".docx", ".txt", ".rtf", ".pages", ".numbers", ".key"],
            icon: "doc.text",
            isEnabled: false,
            destination: .typeFolder,
            matcher: .byExtension
        ),
        FileType(
            name: "Media",
            extensions: [".jpg", ".jpeg", ".png", ".gif", ".webp", ".heic", ".mp4", ".mov", ".avi"],
            icon: "photo",
            isEnabled: false,
            destination: .typeFolder,
            matcher: .byExtensionExcludingPattern
        ),
        FileType(
            name: "Archives",
            extensions: [".zip", ".dmg", ".pkg", ".csv", ".json", ".xml", ".log"],
            icon: "archivebox",
            isEnabled: false,
            destination: .typeFolder,
            matcher: .byExtension
        )
    ]
    
    @Published var sourceFolder: URL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Desktop")
    @Published var destinationFolder: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents").appendingPathComponent(rackOffFolderName)
    @Published var schedule: Schedule = .manual
    @Published var organizationMode: OrganizationMode = .quickArchive
    @Published var lastRun: Date?
    @Published var canUndo: Bool = false
    @Published var isProcessing: Bool = false
    @Published var currentProgress: (current: Int, total: Int) = (0, 0)
    @Published var dailyCleaningHour: Int = 9
    @Published var dailyCleaningMinute: Int = 0
    @Published var totalFilesCleaned: Int = 0
    @Published var totalBytesSaved: Int64 = 0
    @Published var totalCleanSessions: Int = 0
    /// The most recent files RackOff tidied away, newest first. Powers the Peek strip.
    @Published var recentlyRacked: [RackedItem] = []

    /// How many recently-racked items we remember. Enough to browse "the last little while"
    /// without turning into a second Photos library.
    static let maxRecentlyRacked = 40

    // MARK: - Private Properties
    private var lastOperation: [UndoOperation] = []
    private var saveTimer: Timer?
    // Strong, not weak: a weak Timer can be released out from under us, silently
    // killing the daily schedule. We own its lifetime and invalidate it in deinit.
    private var scheduleTimer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private let fileAccessQueue = DispatchQueue(label: "com.pablo.rackoff.fileaccess")
    private let shouldPersistPreferences: Bool
    private let shouldSendNotifications: Bool
    
    // MARK: - Initialization
    init(
        loadStoredPreferences: Bool = true,
        sourceFolder: URL? = nil,
        destinationFolder: URL? = nil,
        requestNotifications: Bool = true,
        sendNotifications: Bool = true,
        ensureFolderAccess: Bool = true,
        setupSchedule: Bool = true,
        persistPreferences: Bool = true
    ) {
        let usesInjectedFolders = sourceFolder != nil || destinationFolder != nil

        self.shouldPersistPreferences = persistPreferences
        self.shouldSendNotifications = sendNotifications

        if loadStoredPreferences {
            // Load preferences first (but don't trust the paths yet)
            loadPreferences()
        }

        if let sourceFolder {
            self.sourceFolder = sourceFolder
        }

        if let destinationFolder {
            self.destinationFolder = destinationFolder
        }

        if ensureFolderAccess && !usesInjectedFolders {
            // CRITICAL: Ensure we have proper access to real folders, not sandbox.
            // This must happen before real user file operations.
            ensureRealFolderAccess()
        }

        if requestNotifications && sendNotifications {
            requestNotificationPermissions()
        }

        if setupSchedule {
            setupScheduling()
        }
    }
    
    deinit {
        // Clean up timers to prevent memory leaks
        saveTimer?.invalidate()
        saveTimer = nil
        scheduleTimer?.invalidate()
        scheduleTimer = nil
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }
    
    // MARK: - Public Methods
    
    /// - Parameter allowImmediateCatchUp: whether a past-due clean may run right now.
    ///   True on launch/wake (we genuinely missed it). False when the user just flipped
    ///   the toggle on — enabling daily-clean at 3pm shouldn't trigger a surprise clean;
    ///   there was no missed run, the schedule didn't exist this morning.
    private func setupScheduling(allowImmediateCatchUp: Bool = true) {
        // Cancel existing schedule timer and wake observer; we rebuild them below.
        scheduleTimer?.invalidate()
        scheduleTimer = nil
        if let observer = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            wakeObserver = nil
        }

        switch schedule {
        case .manual:
            // Manual mode - only clean when user clicks button
            break

        case .onLaunch:
            // Run immediately on launch
            Task {
                let _ = await vacuum()
            }

        case .daily:
            // Two-pronged so the promise actually holds on a real (sleeping) laptop:
            //  1. A forward timer for the case where the app is running across 9 AM.
            //  2. A catch-up check — now, and on every wake — that runs the clean if
            //     today's scheduled time has already passed and we haven't run since.
            //     A bare 24h Timer doesn't survive sleep, so the catch-up is what
            //     makes "daily at 9" true for someone who shuts the lid each night.
            scheduleDailyVacuum()
            observeWake()
            if allowImmediateCatchUp {
                runDailyCatchUpIfNeeded()
            }
        }
    }

    /// Run today's clean if it's due and we haven't done it yet. "Due" = the scheduled
    /// time has passed today, and our last successful run was before that time.
    /// Not `private` so the smoke test can exercise this trust-critical path directly.
    func runDailyCatchUpIfNeeded() {
        guard schedule == .daily else { return }

        let calendar = Calendar.current
        let now = Date()

        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = dailyCleaningHour
        components.minute = dailyCleaningMinute
        components.second = 0
        guard let todaysScheduledTime = calendar.date(from: components) else { return }

        // Not time yet today — the forward timer will handle it.
        guard now >= todaysScheduledTime else { return }

        // Already cleaned at or after today's scheduled time — nothing to catch up.
        if let lastRun, lastRun >= todaysScheduledTime { return }

        Task {
            let _ = await vacuum()
        }
    }

    private func observeWake() {
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                // A bare Timer scheduled before sleep won't have fired; rebuild the
                // forward timer and catch up on anything we missed while asleep.
                self.scheduleDailyVacuum()
                self.runDailyCatchUpIfNeeded()
            }
        }
    }
    
    private func scheduleDailyVacuum() {
        // Invalidate any existing timer first — this is called again on wake and after
        // each fire, so without this we'd stack up timers.
        scheduleTimer?.invalidate()

        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        dateComponents.hour = dailyCleaningHour
        dateComponents.minute = dailyCleaningMinute
        dateComponents.second = 0
        
        guard let targetDate = calendar.date(from: dateComponents) else { return }
        
        // If it's already past the scheduled time today, schedule for tomorrow
        let now = Date()
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: targetDate) else { return }
        let scheduledDate = targetDate > now ? targetDate : tomorrow
        
        let timeInterval = scheduledDate.timeIntervalSince(now)
        
        // Schedule the timer
        scheduleTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                let _ = await self.vacuum()
                // Reschedule for next day
                self.scheduleDailyVacuum()
            }
        }
    }
    
    func updateSchedule(_ newSchedule: Schedule) {
        schedule = newSchedule
        // User-initiated: don't fire a clean the instant they enable daily mode.
        setupScheduling(allowImmediateCatchUp: false)
        savePreferences()
    }
    
    func updateDailyCleaningTime(hour: Int, minute: Int) {
        dailyCleaningHour = hour
        dailyCleaningMinute = minute
        savePreferences()
        
        // Reschedule if currently using daily schedule. Don't catch up immediately —
        // adjusting the time picker shouldn't kick off a clean on the spot.
        if schedule == .daily {
            setupScheduling(allowImmediateCatchUp: false)
        }
    }
    
    func updateOrganizationMode(_ newMode: OrganizationMode) {
        organizationMode = newMode
        savePreferences()
    }
    
    func toggleFileType(_ fileType: FileType, enabled: Bool) {
        if let index = fileTypes.firstIndex(where: { $0.id == fileType.id }) {
            fileTypes[index].isEnabled = enabled
            // Save preferences with debounce instead of immediately
            debouncedSave()
        }
    }
    
    func updateFileTypeDestination(_ fileType: FileType, destination: FileDestination) {
        if let index = fileTypes.firstIndex(where: { $0.id == fileType.id }) {
            fileTypes[index].destination = destination
            debouncedSave()
        }
    }
    
    func updateFileTypeCustomDestination(_ fileType: FileType, url: URL?) {
        if let index = fileTypes.firstIndex(where: { $0.id == fileType.id }) {
            fileTypes[index].customDestination = url
            if url != nil {
                fileTypes[index].destination = .custom
            }
            debouncedSave()
        }
    }
    
    func updateFileTypeExtensions(_ fileType: FileType, extensions: [String]) {
        if let index = fileTypes.firstIndex(where: { $0.id == fileType.id }) {
            fileTypes[index].extensions = extensions
            debouncedSave()
        }
    }
    
    func updateDestinationFolder(_ url: URL) {
        destinationFolder = url
        savePreferences()
    }
    
    func undoLastClean() async -> (restoredCount: Int, errors: [String]) {
        guard canUndo && !lastOperation.isEmpty else {
            return (0, ["No operations to undo"])
        }
        
        isProcessing = true
        defer { 
            isProcessing = false
            currentProgress = (0, 0)
        }
        
        var restoredCount = 0
        var errors: [String] = []
        
        currentProgress = (0, lastOperation.count)
        
        for operation in lastOperation {
            currentProgress.current += 1
            
            // Allow UI to update
            if currentProgress.current % 10 == 0 {
                await Task.yield()
            }
            
            do {
                // Move file back to original location
                try FileManager.default.moveItem(at: operation.destination, to: operation.source)
                restoredCount += 1
            } catch {
                errors.append("Failed to restore \(operation.source.lastPathComponent): \(error.localizedDescription)")
            }
        }
        
        // Drop the restored files from the Peek strip — they're back on the desktop,
        // so a "recently racked" entry (and its reveal target) would now be a dead end.
        let restoredDestinations = Set(lastOperation.map { $0.destination })
        if !restoredDestinations.isEmpty {
            recentlyRacked.removeAll { restoredDestinations.contains($0.destination) }
            saveRecentlyRacked()
        }

        // Clear undo history after undoing
        lastOperation = []
        canUndo = false

        // Show notification
        showUndoNotification(filesRestored: restoredCount, errors: errors)
        
        return (restoredCount, errors)
    }
    
    func clearUndoHistory() {
        lastOperation = []
        canUndo = false
    }
    
    func vacuum() async -> (movedCount: Int, totalBytes: Int64, errors: [String]) {
        await MainActor.run {
            isProcessing = true
        }
        defer {
            Task { @MainActor in
                isProcessing = false
            }
        }


        var movedCount = 0
        var totalBytes: Int64 = 0
        var errors: [String] = []
        var newUndoOperations: [UndoOperation] = []
        var newlyRacked: [RackedItem] = []
        
        // First, count total files to move
        var totalFiles = 0
        let enabledFileTypes = activeFileTypes()

        for fileType in enabledFileTypes {
            let files = findFiles(ofType: fileType)
            totalFiles += files.count
        }
        await MainActor.run {
            currentProgress = (0, totalFiles)
        }
        
        // Process each enabled file type
        for fileType in enabledFileTypes {
            let files = findFiles(ofType: fileType)

            for file in files {
                // Update progress
                await MainActor.run {
                    currentProgress.current += 1
                }
                
                // Allow UI to update for large operations
                if currentProgress.current % 10 == 0 {
                    await Task.yield()
                }
                
                let fileName = file.lastPathComponent
                let destinationFolder = getDestinationFolder(for: fileType, fileURL: file)

                // Create destination folder if it doesn't exist
                let folderExisted = FileManager.default.fileExists(atPath: destinationFolder.path)
                do {
                    try FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
                    if shouldSendNotifications && !folderExisted {
                        // Notify user that a new folder was created
                        // Check notification permissions before sending
                        let settings = await UNUserNotificationCenter.current().notificationSettings()
                        if settings.authorizationStatus == .authorized {
                            let folderName = destinationFolder.lastPathComponent
                            let notification = UNMutableNotificationContent()
                            notification.title = "📁 New Archive Folder"
                            notification.body = "Created folder: \(folderName)"
                            notification.sound = nil // Silent notification

                            let request = UNNotificationRequest(
                                identifier: "folder-created-\(folderName)",
                                content: notification,
                                trigger: nil
                            )

                            try? await UNUserNotificationCenter.current().add(request)
                        }
                    }
                } catch {
                    errors.append("Failed to create folder: \(error.localizedDescription)")
                    continue
                }
                
                var destination = destinationFolder.appendingPathComponent(fileName)
                
                // If file already exists in destination, add a number suffix
                if FileManager.default.fileExists(atPath: destination.path) {
                    let nameWithoutExtension = file.deletingPathExtension().lastPathComponent
                    let fileExtension = file.pathExtension
                    var counter = 2
                    
                    repeat {
                        let newName = "\(nameWithoutExtension) \(counter).\(fileExtension)"
                        destination = destinationFolder.appendingPathComponent(newName)
                        counter += 1
                    } while FileManager.default.fileExists(atPath: destination.path) && counter < 100
                }
                

                // SAFETY CHECK: Verify source file exists
                guard FileManager.default.fileExists(atPath: file.path) else {
                    errors.append("Source file not found: \(fileName)")
                    continue
                }

                do {
                    // Get file size and original creation date before moving
                    let fileAttributes = try FileManager.default.attributesOfItem(atPath: file.path)
                    let fileSize = fileAttributes[.size] as? Int64 ?? 0
                    let originalCreationDate = fileAttributes[.creationDate] as? Date

                    // Perform the move
                    try FileManager.default.moveItem(at: file, to: destination)

                    // Restore original creation date if we captured it
                    if let originalDate = originalCreationDate {
                        do {
                            try FileManager.default.setAttributes([.creationDate: originalDate], ofItemAtPath: destination.path)
                        } catch {
                        }
                    }

                    // SAFETY CHECK: Verify the move was successful
                    if FileManager.default.fileExists(atPath: destination.path) {
                        movedCount += 1
                        totalBytes += fileSize

                        // Track for undo
                        newUndoOperations.append(UndoOperation(
                            source: file,
                            destination: destination,
                            timestamp: Date()
                        ))

                        // Track for the Peek strip so the user can still see (and reach)
                        // what just got tidied. Use the file's own creation date so it
                        // lands in the right spot on the mental timeline.
                        newlyRacked.append(RackedItem(
                            name: fileName,
                            icon: fileType.icon,
                            accentName: fileType.name,
                            destination: destination,
                            date: originalCreationDate ?? Date()
                        ))
                    } else {
                        errors.append("File move verification failed for: \(fileName)")
                    }

                } catch {
                    errors.append("Failed to move \(file.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }
        
        // Store undo operations if any files were moved
        if !newUndoOperations.isEmpty {
            lastOperation = newUndoOperations
            canUndo = true
        }
        
        // Update lifetime stats
        if movedCount > 0 {
            totalFilesCleaned += movedCount
            totalBytesSaved += totalBytes
            totalCleanSessions += 1
        }

        // Prepend this sweep to the Peek strip, newest first, capped so it stays a
        // glance and not an archive.
        if !newlyRacked.isEmpty {
            recentlyRacked = (newlyRacked.reversed() + recentlyRacked)
            if recentlyRacked.count > Self.maxRecentlyRacked {
                recentlyRacked = Array(recentlyRacked.prefix(Self.maxRecentlyRacked))
            }
            saveRecentlyRacked()
        }
        
        // Update last run and show notification
        lastRun = Date()
        savePreferences()
        showNotification(filesVacuumed: movedCount, errors: errors)
        
        await MainActor.run {
            currentProgress = (0, 0)
        }
        return (movedCount, totalBytes, errors)
    }

    private func activeFileTypes() -> [FileType] {
        fileTypes.filter { fileType in
            fileType.isEnabled && !(organizationMode == .smartClean && fileType.destination == .skip)
        }
    }

    private func getFileDate(for fileURL: URL?) -> Date {
        guard let fileURL = fileURL else {
            return Date()
        }

        do {
            let resourceValues = try fileURL.resourceValues(forKeys: [.creationDateKey])
            let creationDate = resourceValues.creationDate ?? Date()
            return creationDate
        } catch {
            let fallbackDate = Date()
            return fallbackDate
        }
    }

    private func getDestinationFolder(for fileType: FileType, fileURL: URL? = nil) -> URL {
        // Get the date to use (file creation date if available, otherwise today)
        let dateToUse = getFileDate(for: fileURL)

        let resultFolder: URL

        switch organizationMode {
        case .quickArchive:
            // Everything goes to monthly folders based on the file's own creation
            // date. Monthly is the sweet spot for browsing later — ~12 folders a year,
            // each with real content to scroll, instead of a wall of near-empty days.
            //
            // Format is "2026-06 June": the yyyy-MM prefix keeps Finder sorting the
            // months chronologically, while the month name makes the folder read like
            // a human wrote it, not a robot. The month name is localized, so it's
            // friendly in whatever language the user runs macOS in.
            let yearFormatter = DateFormatter()
            yearFormatter.dateFormat = "yyyy"
            let yearString = yearFormatter.string(from: dateToUse)
            
            let monthFormatter = DateFormatter()
            monthFormatter.dateFormat = "MM-MMMM" // e.g. "07-July"
            let monthString = monthFormatter.string(from: dateToUse)
            
            resultFolder = destinationFolder
                .appendingPathComponent(yearString)
                .appendingPathComponent(monthString)

        case .sortByType:
            // Everything goes to type folders
            resultFolder = destinationFolder.appendingPathComponent(fileType.name)

        case .smartClean:
            // Use per-file-type destination settings
            switch fileType.destination {
            case .daily:
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let dateString = dateFormatter.string(from: dateToUse)
                resultFolder = destinationFolder.appendingPathComponent(dateString)

            case .weekly:
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-'W'ww"
                let dateString = dateFormatter.string(from: dateToUse)
                resultFolder = destinationFolder.appendingPathComponent(dateString)

            case .monthly:
                let yearFormatter = DateFormatter()
                yearFormatter.dateFormat = "yyyy"
                let yearString = yearFormatter.string(from: dateToUse)
                
                let monthFormatter = DateFormatter()
                monthFormatter.dateFormat = "MM-MMMM" // e.g. "07-July"
                let monthString = monthFormatter.string(from: dateToUse)
                
                resultFolder = destinationFolder
                    .appendingPathComponent(yearString)
                    .appendingPathComponent(monthString)

            case .typeFolder:
                resultFolder = destinationFolder.appendingPathComponent(fileType.name)

            case .custom:
                // Use custom destination if set, otherwise fall back to type folder
                resultFolder = fileType.customDestination ?? destinationFolder.appendingPathComponent(fileType.name)

            case .skip:
                // This case shouldn't happen since we filter enabled file types
                // But return a safe default
                resultFolder = destinationFolder.appendingPathComponent(fileType.name)
            }
        }

        return resultFolder
    }
    
    private func findFiles(ofType fileType: FileType) -> [URL] {
        var results: [URL] = []
        let fileManager = FileManager.default

        do {
            let contents = try fileManager.contentsOfDirectory(at: sourceFolder, includingPropertiesForKeys: [.isRegularFileKey])

            for item in contents {
                // Skip directories and hidden files
                let resourceValues = try? item.resourceValues(forKeys: [.isRegularFileKey, .isHiddenKey])
                guard let isRegularFile = resourceValues?.isRegularFile,
                      let isHidden = resourceValues?.isHidden,
                      isRegularFile && !isHidden else { continue }

                if matchesFileType(item, fileType: fileType) {
                    results.append(item)
                }
            }
        } catch {
        }

        return results
    }
    
    private func matchesFileType(_ url: URL, fileType: FileType) -> Bool {
        let filename = url.lastPathComponent.lowercased()

        switch fileType.matcher {
        case .byExtension:
            // Simple extension matching
            let matches = fileType.extensions.contains(where: { filename.hasSuffix($0) })
            return matches

        case .byFilenamePattern:
            // Match by filename pattern (e.g., screenshots)
            let patterns = getPatterns(for: fileType)
            let hasPattern = patterns.contains(where: { filename.contains($0.lowercased()) })
            let hasExtension = fileType.extensions.contains(where: { filename.hasSuffix($0) })
            return hasPattern && hasExtension

        case .byExtensionExcludingPattern:
            // Match by extension but exclude certain patterns (e.g., media excluding screenshots)
            let hasExtension = fileType.extensions.contains(where: { filename.hasSuffix($0) })
            let excludePatterns = getExcludePatterns(for: fileType)
            let hasExcludedPattern = excludePatterns.contains(where: { filename.contains($0.lowercased()) })
            return hasExtension && !hasExcludedPattern
        }
    }
    
    private func getPatterns(for fileType: FileType) -> [String] {
        // Define patterns for each file type that uses pattern matching
        switch fileType.name {
        case "Screenshots":
            // Comprehensive list of screenshot patterns
            // Including various macOS screenshot naming conventions
            return [
                "screenshot", "screen shot", "screen recording", "screen capture",
                "Screenshot", "Screen Shot", "Screen Recording", "Screen Capture",
                "CleanShot", "cleanshot", "Cleanshot",
                "Capture", "capture",
                "Snagit", "snagit",
                "скриншот", "снимок экрана",  // Russian
                "captura de pantalla", "Captura de pantalla",  // Spanish
                "capture d'écran", "Capture d'écran"  // French
            ]
        default:
            return []
        }
    }
    
    private func getExcludePatterns(for fileType: FileType) -> [String] {
        // Define patterns to exclude for each file type
        switch fileType.name {
        case "Media":
            // Exclude all screenshot patterns from regular media
            return [
                "screenshot", "screen shot", "screen recording", "screen capture",
                "Screenshot", "Screen Shot", "Screen Recording", "Screen Capture",
                "CleanShot", "cleanshot", "Cleanshot",
                "Capture", "capture",
                "Snagit", "snagit",
                "скриншот", "снимок экрана",  // Russian
                "captura de pantalla", "Captura de pantalla",  // Spanish
                "capture d'écran", "Capture d'écran"  // French
            ]
        default:
            return []
        }
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                NSLog("❌ ERROR: Notification permission error: \(error.localizedDescription)")
            } else if granted {
                NSLog("✅ SUCCESS: Notification permissions granted")
            } else {
                NSLog("⚠️ WARNING: Notification permissions denied")
            }
        }
    }

    private func sendNotification(title: String, body: String, subtitle: String? = nil) {
        guard shouldSendNotifications else { return }

        // Check if we have permission to send notifications
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                NSLog("⚠️ WARNING: Notification permission not granted, cannot send notification: \(title)")
                return
            }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            if let subtitle = subtitle {
                content.subtitle = subtitle
            }
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    NSLog("❌ ERROR: Failed to send notification: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func showNotification(filesVacuumed count: Int, errors: [String] = []) {
        let title = "RackOff Complete"
        let subtitle: String?
        let body: String

        if !errors.isEmpty {
            body = "Moved \(count) file\(count == 1 ? "" : "s") with \(errors.count) error\(errors.count == 1 ? "" : "s")"
            subtitle = "Some files couldn't be moved"
        } else if count > 0 {
            body = "Racked off \(count) file\(count == 1 ? "" : "s") to archive"
            subtitle = nil
        } else {
            body = "Desktop already clean"
            subtitle = nil
        }

        sendNotification(title: title, body: body, subtitle: subtitle)
    }
    
    private func showUndoNotification(filesRestored count: Int, errors: [String] = []) {
        let title = "Undo Complete"
        let subtitle: String?
        let body: String

        if !errors.isEmpty {
            body = "Restored \(count) file\(count == 1 ? "" : "s") with \(errors.count) error\(errors.count == 1 ? "" : "s")"
            subtitle = "Some files couldn't be restored"
        } else if count > 0 {
            body = "Restored \(count) file\(count == 1 ? "" : "s") to desktop"
            subtitle = nil
        } else {
            body = "Nothing to undo"
            subtitle = nil
        }

        sendNotification(title: title, body: body, subtitle: subtitle)
    }
    
    private func loadPreferences() {
        // Load from UserDefaults
        if let savedSchedule = UserDefaults.standard.string(forKey: "schedule"),
           let schedule = Schedule(rawValue: savedSchedule) {
            self.schedule = schedule
        }
        
        // Organization mode is intentionally NOT restored. RackOff has one job —
        // sweep everything to dated folders — so we always stay in .quickArchive.
        // (The engine still supports other modes for tests, just not the product.)

        // Try to load from saved bookmark first (for sandbox)
        if let bookmarkURL = loadDesktopBookmark() {
            self.sourceFolder = bookmarkURL
        } else if let sourceURL = UserDefaults.standard.url(forKey: "sourceFolder") {
            self.sourceFolder = sourceURL
        } else if let sourcePath = UserDefaults.standard.string(forKey: "sourceFolder") {
            // Handle legacy string paths (with ~ expansion)
            let expandedPath = NSString(string: sourcePath).expandingTildeInPath
            self.sourceFolder = URL(fileURLWithPath: expandedPath)
        }

        // Try to load from saved bookmark first (for sandbox)
        if let bookmarkURL = loadDocumentsBookmark() {
            self.destinationFolder = bookmarkURL
        } else if let destURL = UserDefaults.standard.url(forKey: "destinationFolder") {
            self.destinationFolder = destURL
        } else if let destPath = UserDefaults.standard.string(forKey: "destinationFolder") {
            // Handle legacy string paths (with ~ expansion)
            let expandedPath = NSString(string: destPath).expandingTildeInPath
            self.destinationFolder = URL(fileURLWithPath: expandedPath)
        }
        
        if let lastRunDate = UserDefaults.standard.object(forKey: "lastRun") as? Date {
            self.lastRun = lastRunDate
        }
        
        // Load daily cleaning time preferences
        if UserDefaults.standard.object(forKey: "dailyCleaningHour") != nil {
            self.dailyCleaningHour = UserDefaults.standard.integer(forKey: "dailyCleaningHour")
        }
        
        if UserDefaults.standard.object(forKey: "dailyCleaningMinute") != nil {
            self.dailyCleaningMinute = UserDefaults.standard.integer(forKey: "dailyCleaningMinute")
        }
        
        if UserDefaults.standard.object(forKey: "totalFilesCleaned") != nil {
            self.totalFilesCleaned = UserDefaults.standard.integer(forKey: "totalFilesCleaned")
        }
        
        if UserDefaults.standard.object(forKey: "totalBytesSaved") != nil {
            if let bytesValue = UserDefaults.standard.object(forKey: "totalBytesSaved") as? Int64 {
                self.totalBytesSaved = bytesValue
            } else {
                self.totalBytesSaved = Int64(UserDefaults.standard.integer(forKey: "totalBytesSaved"))
            }
        }
        
        if UserDefaults.standard.object(forKey: "totalCleanSessions") != nil {
            self.totalCleanSessions = UserDefaults.standard.integer(forKey: "totalCleanSessions")
        }
        
        // Load file type preferences
        for index in fileTypes.indices {
            let fileType = fileTypes[index]
            let enabledKey = "fileType_\(fileType.name)"
            if UserDefaults.standard.object(forKey: enabledKey) != nil {
                fileTypes[index].isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
            }
            
            let destinationKey = "fileTypeDestination_\(fileType.name)"
            if let savedDestination = UserDefaults.standard.string(forKey: destinationKey),
               let destination = FileDestination(rawValue: savedDestination) {
                fileTypes[index].destination = destination
            }
            
            let customDestKey = "fileTypeCustomDest_\(fileType.name)"
            if let customDestURL = UserDefaults.standard.url(forKey: customDestKey) {
                fileTypes[index].customDestination = customDestURL
            }
            
            let extensionsKey = "fileTypeExtensions_\(fileType.name)"
            if let savedExtensions = UserDefaults.standard.array(forKey: extensionsKey) as? [String] {
                fileTypes[index].extensions = savedExtensions
            }
        }

        loadRecentlyRacked()
    }
    
    private func savePreferences() {
        guard shouldPersistPreferences else { return }

        UserDefaults.standard.set(schedule.rawValue, forKey: "schedule")
        UserDefaults.standard.set(organizationMode.rawValue, forKey: "organizationMode")
        UserDefaults.standard.set(sourceFolder, forKey: "sourceFolder")
        UserDefaults.standard.set(destinationFolder, forKey: "destinationFolder")
        UserDefaults.standard.set(lastRun, forKey: "lastRun")
        UserDefaults.standard.set(dailyCleaningHour, forKey: "dailyCleaningHour")
        UserDefaults.standard.set(dailyCleaningMinute, forKey: "dailyCleaningMinute")
        UserDefaults.standard.set(totalFilesCleaned, forKey: "totalFilesCleaned")
        UserDefaults.standard.set(totalBytesSaved, forKey: "totalBytesSaved")
        UserDefaults.standard.set(totalCleanSessions, forKey: "totalCleanSessions")
        
        // Save file type preferences
        for fileType in fileTypes {
            let enabledKey = "fileType_\(fileType.name)"
            UserDefaults.standard.set(fileType.isEnabled, forKey: enabledKey)
            
            let destinationKey = "fileTypeDestination_\(fileType.name)"
            UserDefaults.standard.set(fileType.destination.rawValue, forKey: destinationKey)
            
            let customDestKey = "fileTypeCustomDest_\(fileType.name)"
            if let customDest = fileType.customDestination {
                UserDefaults.standard.set(customDest, forKey: customDestKey)
            } else {
                UserDefaults.standard.removeObject(forKey: customDestKey)
            }
            
            let extensionsKey = "fileTypeExtensions_\(fileType.name)"
            UserDefaults.standard.set(fileType.extensions, forKey: extensionsKey)
        }
    }
    
    private func saveRecentlyRacked() {
        guard shouldPersistPreferences else { return }

        do {
            let data = try JSONEncoder().encode(recentlyRacked)
            UserDefaults.standard.set(data, forKey: "recentlyRacked")
        } catch {
            NSLog("⚠️ WARNING: Failed to encode recentlyRacked: \(error.localizedDescription)")
        }
    }

    private func loadRecentlyRacked() {
        guard let data = UserDefaults.standard.data(forKey: "recentlyRacked") else { return }

        do {
            let items = try JSONDecoder().decode([RackedItem].self, from: data)
            // Only surface items whose file is still where we left it; a restored or
            // hand-moved file shouldn't haunt the Peek strip.
            recentlyRacked = items.filter { FileManager.default.fileExists(atPath: $0.destination.path) }
        } catch {
            NSLog("⚠️ WARNING: Failed to decode recentlyRacked: \(error.localizedDescription)")
        }
    }

    private func debouncedSave() {
        // Cancel existing timer
        saveTimer?.invalidate()

        // Start new timer - save after 500ms of inactivity
        saveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.savePreferences()
            }
        }
    }

    // MARK: - Real Folder Access (Critical for Sandbox)
    private func ensureRealFolderAccess() {

        // Step 1: Ensure Desktop access
        ensureDesktopAccess()

        // Step 2: Ensure Documents access
        ensureDocumentsAccess()

        // Step 3: Verify we're not using sandbox paths
        let sandboxPath = "Library/Containers/com.pablo.rackoff"

        if sourceFolder.path.contains(sandboxPath) {
            NSLog("⚠️ WARNING: Source folder is in sandbox container! Resetting to real Desktop")
            sourceFolder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
            requestDesktopAccess()
        }

        if destinationFolder.path.contains(sandboxPath) {
            NSLog("⚠️ WARNING: Destination folder is in sandbox container! Resetting to real Documents/Archive")
            destinationFolder = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Documents")
                .appendingPathComponent(rackOffFolderName)
            requestDocumentsAccess()
        }

        // Step 4: Create real archive folder if needed
        do {
            try FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
            NSLog("✅ SUCCESS: Archive folder verified/created at: \(destinationFolder.path)")
        } catch {
            NSLog("❌ ERROR: Failed to create archive folder at \(destinationFolder.path): \(error.localizedDescription)")
            sendNotification(
                title: "Archive Setup Failed",
                body: "Unable to create archive folder. Please check folder permissions."
            )
        }

        NSLog("  Source: \(sourceFolder.path)")
        NSLog("  Destination: \(destinationFolder.path)")
    }

    // MARK: - Sandbox Desktop Access
    private func ensureDesktopAccess() {
        // Try to access the real desktop first
        let realDesktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")

        // Check if we can access it
        if FileManager.default.isReadableFile(atPath: realDesktop.path) {
            // Try to read it to verify sandbox permissions
            do {
                let _ = try FileManager.default.contentsOfDirectory(at: realDesktop, includingPropertiesForKeys: nil)

                // Update sourceFolder to the real desktop
                sourceFolder = realDesktop

                // Save the bookmark for persistence
                saveDesktopBookmark(for: realDesktop)

            } catch {
                // Fall back to requesting access
                requestDesktopAccess()
            }
        } else {
            requestDesktopAccess()
        }
    }

    private func requestDesktopAccess() {
        DispatchQueue.main.async { [weak self] in
            let panel = NSOpenPanel()
            panel.message = "RackOff needs access to your Desktop to clean files"
            panel.prompt = "Grant Access"
            panel.allowsMultipleSelection = false
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")

            let result = panel.runModal()
            if result == .OK, let url = panel.url {
                self?.sourceFolder = url
                self?.saveDesktopBookmark(for: url)
            }
        }
    }

    private func saveDesktopBookmark(for url: URL) {
        guard shouldPersistPreferences else { return }

        do {
            let bookmarkData = try url.bookmarkData(options: .withSecurityScope)
            UserDefaults.standard.set(bookmarkData, forKey: "desktopBookmark")
            NSLog("✅ SUCCESS: Desktop bookmark saved for \(url.path)")
        } catch {
            NSLog("❌ ERROR: Failed to save desktop bookmark: \(error.localizedDescription)")
            sendNotification(title: "Desktop Access Error",
                           body: "Unable to save desktop access permissions. You may need to grant access again next time.")
        }
    }

    private func loadDesktopBookmark() -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: "desktopBookmark") else {
            NSLog("⚠️ WARNING: No desktop bookmark found in UserDefaults")
            return nil
        }

        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)

            if isStale {
                NSLog("⚠️ WARNING: Desktop bookmark is stale, requesting new access")
                sendNotification(title: "Desktop Access Expired",
                               body: "Desktop access permissions have expired. Please grant access again.")
                return nil
            }

            if url.startAccessingSecurityScopedResource() {
                NSLog("✅ SUCCESS: Desktop bookmark resolved for \(url.path)")
                return url
            } else {
                NSLog("❌ ERROR: Failed to start accessing security scoped resource for desktop")
                return nil
            }
        } catch {
            NSLog("❌ ERROR: Failed to resolve desktop bookmark: \(error.localizedDescription)")
            sendNotification(title: "Desktop Access Error",
                           body: "Unable to restore desktop access permissions. Please grant access again.")
        }

        return nil
    }

    // MARK: - Sandbox Documents Access

    /// One-time migration from the old "Archive" folder to "Stash". If a user (or an
    /// earlier build) already tidied into ~/Documents/Archive, carry that history over
    /// rather than silently starting a fresh empty folder — losing track of someone's
    /// stuff is exactly the trust break RackOff can't afford. Only renames when the old
    /// folder exists AND the new one doesn't, so it's safe to call on every launch.
    private func migrateLegacyArchiveFolderIfNeeded(in documents: URL) {
        let legacy = documents.appendingPathComponent("Archive")
        let current = documents.appendingPathComponent(rackOffFolderName)

        guard FileManager.default.fileExists(atPath: legacy.path),
              !FileManager.default.fileExists(atPath: current.path) else {
            return
        }

        do {
            try FileManager.default.moveItem(at: legacy, to: current)
            NSLog("✅ SUCCESS: Migrated legacy Archive folder to \(rackOffFolderName)")
        } catch {
            // Non-fatal: if the rename fails we just keep using the new folder name.
            // The old files stay put in Archive; nothing is lost, just not carried over.
            NSLog("⚠️ WARNING: Could not migrate Archive → \(rackOffFolderName): \(error.localizedDescription)")
        }
    }

    private func ensureDocumentsAccess() {
        // Try to access the real Documents folder first
        let realDocuments = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
        migrateLegacyArchiveFolderIfNeeded(in: realDocuments)
        let archiveFolder = realDocuments.appendingPathComponent(rackOffFolderName)

        // Check if we can access it
        if FileManager.default.isReadableFile(atPath: realDocuments.path) {
            // Try to read it to verify sandbox permissions
            do {
                let _ = try FileManager.default.contentsOfDirectory(at: realDocuments, includingPropertiesForKeys: nil)

                // Update destinationFolder to the real documents
                destinationFolder = archiveFolder

                // Save the bookmark for persistence
                saveDocumentsBookmark(for: realDocuments)

            } catch {
                // Fall back to requesting access
                requestDocumentsAccess()
            }
        } else {
            requestDocumentsAccess()
        }
    }

    private func requestDocumentsAccess() {
        DispatchQueue.main.async { [weak self] in
            let panel = NSOpenPanel()
            panel.message = "RackOff needs access to your Documents folder to store archived files"
            panel.prompt = "Grant Access"
            panel.allowsMultipleSelection = false
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")

            let result = panel.runModal()
            if result == .OK, let url = panel.url {
                self?.destinationFolder = url.appendingPathComponent(rackOffFolderName)
                self?.saveDocumentsBookmark(for: url)
            }
        }
    }

    private func saveDocumentsBookmark(for url: URL) {
        guard shouldPersistPreferences else { return }

        do {
            let bookmarkData = try url.bookmarkData(options: .withSecurityScope)
            UserDefaults.standard.set(bookmarkData, forKey: "documentsBookmark")
            NSLog("✅ SUCCESS: Documents bookmark saved for \(url.path)")
        } catch {
            NSLog("❌ ERROR: Failed to save documents bookmark: \(error.localizedDescription)")
            sendNotification(title: "Documents Access Error",
                           body: "Unable to save Documents access permissions. You may need to grant access again next time.")
        }
    }

    private func loadDocumentsBookmark() -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: "documentsBookmark") else {
            NSLog("⚠️ WARNING: No documents bookmark found in UserDefaults")
            return nil
        }

        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)

            if isStale {
                NSLog("⚠️ WARNING: Documents bookmark is stale, requesting new access")
                sendNotification(title: "Documents Access Expired",
                               body: "Documents access permissions have expired. Please grant access again.")
                return nil
            }

            if url.startAccessingSecurityScopedResource() {
                let archiveURL = url.appendingPathComponent(rackOffFolderName)
                NSLog("✅ SUCCESS: Documents bookmark resolved for \(archiveURL.path)")
                return archiveURL
            } else {
                NSLog("❌ ERROR: Failed to start accessing security scoped resource for documents")
                return nil
            }
        } catch {
            NSLog("❌ ERROR: Failed to resolve documents bookmark: \(error.localizedDescription)")
            sendNotification(title: "Documents Access Error",
                           body: "Unable to restore Documents access permissions. Please grant access again.")
        }

        return nil
    }
}
