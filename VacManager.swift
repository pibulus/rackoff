import Foundation
import SwiftUI
import UserNotifications

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
    @Published var destinationFolder: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents").appendingPathComponent("Archive")
    @Published var schedule: Schedule = .manual
    @Published var organizationMode: OrganizationMode = .quickArchive
    @Published var lastRun: Date?
    @Published var canUndo: Bool = false
    @Published var isProcessing: Bool = false
    @Published var currentProgress: (current: Int, total: Int) = (0, 0)
    @Published var dailyCleaningHour: Int = 9
    @Published var dailyCleaningMinute: Int = 0
    
    // MARK: - Private Properties
    private var lastOperation: [UndoOperation] = []
    private var saveTimer: Timer?
    private weak var scheduleTimer: Timer?
    private let fileAccessQueue = DispatchQueue(label: "com.pablo.rackoff.fileaccess")
    
    // MARK: - Initialization
    init() {
        NSLog("🔍 DEBUG: VacManager init() started")

        // Load preferences first (but don't trust the paths yet)
        loadPreferences()

        // CRITICAL: Ensure we have proper access to real folders, not sandbox
        // This MUST happen before any file operations
        ensureRealFolderAccess()

        // Request notification permissions
        requestNotificationPermissions()

        NSLog("🔍 DEBUG: About to setup scheduling with schedule: \(schedule)")
        // Setup scheduling
        setupScheduling()
        NSLog("🔍 DEBUG: VacManager init() completed")
    }
    
    deinit {
        // Clean up timers to prevent memory leaks
        saveTimer?.invalidate()
        saveTimer = nil
        scheduleTimer?.invalidate()
        scheduleTimer = nil
    }
    
    // MARK: - Public Methods
    
    private func setupScheduling() {
        // Cancel existing schedule timer
        scheduleTimer?.invalidate()
        
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
            // Schedule daily at 9 AM
            scheduleDailyVacuum()
        }
    }
    
    private func scheduleDailyVacuum() {
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
        setupScheduling()
        savePreferences()
    }
    
    func updateDailyCleaningTime(hour: Int, minute: Int) {
        dailyCleaningHour = hour
        dailyCleaningMinute = minute
        savePreferences()
        
        // Reschedule if currently using daily schedule
        if schedule == .daily {
            setupScheduling()
        }
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
        NSLog("🔍 DEBUG: vacuum() called")
        await MainActor.run {
            isProcessing = true
        }
        defer {
            Task { @MainActor in
                isProcessing = false
            }
        }

        NSLog("🔍 DEBUG: Source folder: \(sourceFolder.path)")
        NSLog("🔍 DEBUG: Destination folder: \(destinationFolder.path)")
        NSLog("🔍 DEBUG: Organization mode: \(organizationMode)")

        var movedCount = 0
        var totalBytes: Int64 = 0
        var errors: [String] = []
        var newUndoOperations: [UndoOperation] = []
        
        // First, count total files to move
        var totalFiles = 0
        let enabledFileTypes = fileTypes.filter({ $0.isEnabled })
        NSLog("🔍 DEBUG: Enabled file types: \(enabledFileTypes.map { $0.name })")

        for fileType in enabledFileTypes {
            let files = findFiles(ofType: fileType)
            NSLog("🔍 DEBUG: Looking for \(fileType.name) files in \(sourceFolder.path)")
            NSLog("🔍 DEBUG: Found \(files.count) \(fileType.name) files: \(files.map { $0.lastPathComponent })")
            totalFiles += files.count
        }
        NSLog("🔍 DEBUG: Total files to process: \(totalFiles)")
        await MainActor.run {
            currentProgress = (0, totalFiles)
        }
        
        // Process each enabled file type
        for fileType in fileTypes.filter({ $0.isEnabled }) {
            let files = findFiles(ofType: fileType)
            NSLog("🔍 DEBUG: Processing \(files.count) \(fileType.name) files")

            for file in files {
                NSLog("🔍 DEBUG: Processing file: \(file.lastPathComponent)")
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
                NSLog("🔍 DEBUG: Destination folder for \(fileName): \(destinationFolder.path)")

                // Create destination folder if it doesn't exist
                let folderExisted = FileManager.default.fileExists(atPath: destinationFolder.path)
                do {
                    try FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
                    if !folderExisted {
                        NSLog("🔍 DEBUG: ✅ Created NEW destination folder: \(destinationFolder.path)")
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
                    } else {
                        NSLog("🔍 DEBUG: ✅ Verified existing destination folder: \(destinationFolder.path)")
                    }
                } catch {
                    NSLog("🔍 DEBUG: ❌ Failed to create folder \(destinationFolder.path): \(error.localizedDescription)")
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
                
                NSLog("🔍 DEBUG: Attempting to move \(file.path) to \(destination.path)")

                // SAFETY CHECK: Verify source file exists
                guard FileManager.default.fileExists(atPath: file.path) else {
                    NSLog("🔍 DEBUG: ERROR - Source file doesn't exist: \(file.path)")
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
                            NSLog("🔍 DEBUG: Restored creation date for \(fileName) to \(originalDate)")
                        } catch {
                            NSLog("🔍 DEBUG: Failed to restore creation date for \(fileName): \(error.localizedDescription)")
                        }
                    }

                    // SAFETY CHECK: Verify the move was successful
                    if FileManager.default.fileExists(atPath: destination.path) {
                        NSLog("🔍 DEBUG: ✅ Successfully moved \(fileName) to \(destination.path)")
                        movedCount += 1
                        totalBytes += fileSize

                        // Track for undo
                        newUndoOperations.append(UndoOperation(
                            source: file,
                            destination: destination,
                            timestamp: Date()
                        ))
                    } else {
                        NSLog("🔍 DEBUG: ❌ CRITICAL ERROR - Move reported success but destination file doesn't exist!")
                        errors.append("File move verification failed for: \(fileName)")
                    }

                } catch {
                    NSLog("🔍 DEBUG: ❌ Failed to move \(fileName): \(error.localizedDescription)")
                    errors.append("Failed to move \(file.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }
        
        // Store undo operations if any files were moved
        if !newUndoOperations.isEmpty {
            lastOperation = newUndoOperations
            canUndo = true
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

    private func getFileDate(for fileURL: URL?) -> Date {
        guard let fileURL = fileURL else {
            NSLog("🔍 DEBUG: No fileURL provided, using current date")
            return Date()
        }

        do {
            let resourceValues = try fileURL.resourceValues(forKeys: [.creationDateKey])
            let creationDate = resourceValues.creationDate ?? Date()
            NSLog("🔍 DEBUG: File \(fileURL.lastPathComponent) creation date: \(creationDate)")
            return creationDate
        } catch {
            NSLog("🔍 DEBUG: Failed to get creation date for \(fileURL.lastPathComponent): \(error.localizedDescription)")
            let fallbackDate = Date()
            NSLog("🔍 DEBUG: Using fallback date: \(fallbackDate)")
            return fallbackDate
        }
    }

    private func getDestinationFolder(for fileType: FileType, fileURL: URL? = nil) -> URL {
        // Get the date to use (file creation date if available, otherwise today)
        let dateToUse = getFileDate(for: fileURL)
        NSLog("🔍 DEBUG: Determining destination folder for \(fileType.name) file: \(fileURL?.lastPathComponent ?? "unknown")")
        NSLog("🔍 DEBUG: Organization mode: \(organizationMode), Date to use: \(dateToUse)")

        let resultFolder: URL

        switch organizationMode {
        case .quickArchive:
            // Everything goes to daily folders based on file creation date
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: dateToUse)
            resultFolder = destinationFolder.appendingPathComponent(dateString)
            NSLog("🔍 DEBUG: Quick Archive mode - creating date folder: \(dateString)")

        case .sortByType:
            // Everything goes to type folders
            resultFolder = destinationFolder.appendingPathComponent(fileType.name)
            NSLog("🔍 DEBUG: Sort by Type mode - using type folder: \(fileType.name)")

        case .smartClean:
            // Use per-file-type destination settings
            NSLog("🔍 DEBUG: Smart Clean mode - file type destination: \(fileType.destination)")
            switch fileType.destination {
            case .daily:
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let dateString = dateFormatter.string(from: dateToUse)
                resultFolder = destinationFolder.appendingPathComponent(dateString)
                NSLog("🔍 DEBUG: Daily destination - creating date folder: \(dateString)")

            case .weekly:
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-'W'ww"
                let dateString = dateFormatter.string(from: dateToUse)
                resultFolder = destinationFolder.appendingPathComponent(dateString)
                NSLog("🔍 DEBUG: Weekly destination - creating week folder: \(dateString)")

            case .monthly:
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM"
                let dateString = dateFormatter.string(from: dateToUse)
                resultFolder = destinationFolder.appendingPathComponent(dateString)
                NSLog("🔍 DEBUG: Monthly destination - creating month folder: \(dateString)")

            case .typeFolder:
                resultFolder = destinationFolder.appendingPathComponent(fileType.name)
                NSLog("🔍 DEBUG: Type folder destination - using: \(fileType.name)")

            case .custom:
                // Use custom destination if set, otherwise fall back to type folder
                resultFolder = fileType.customDestination ?? destinationFolder.appendingPathComponent(fileType.name)
                NSLog("🔍 DEBUG: Custom destination: \(resultFolder.path)")

            case .skip:
                // This case shouldn't happen since we filter enabled file types
                // But return a safe default
                resultFolder = destinationFolder.appendingPathComponent(fileType.name)
                NSLog("🔍 DEBUG: Skip destination (fallback) - using: \(fileType.name)")
            }
        }

        NSLog("🔍 DEBUG: Final destination folder: \(resultFolder.path)")
        return resultFolder
    }
    
    private func findFiles(ofType fileType: FileType) -> [URL] {
        var results: [URL] = []
        let fileManager = FileManager.default

        do {
            let contents = try fileManager.contentsOfDirectory(at: sourceFolder, includingPropertiesForKeys: [.isRegularFileKey])
            NSLog("🔍 DEBUG: Directory contents count: \(contents.count)")

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
            NSLog("🔍 DEBUG: Error reading directory \(sourceFolder.path): \(error.localizedDescription)")
        }

        return results
    }
    
    private func matchesFileType(_ url: URL, fileType: FileType) -> Bool {
        let filename = url.lastPathComponent.lowercased()
        NSLog("🔍 DEBUG: Checking if '\(url.lastPathComponent)' matches file type '\(fileType.name)'")

        switch fileType.matcher {
        case .byExtension:
            // Simple extension matching
            let matches = fileType.extensions.contains(where: { filename.hasSuffix($0) })
            NSLog("🔍 DEBUG: Extension matching for \(fileType.name): \(matches)")
            return matches

        case .byFilenamePattern:
            // Match by filename pattern (e.g., screenshots)
            let patterns = getPatterns(for: fileType)
            let hasPattern = patterns.contains(where: { filename.contains($0.lowercased()) })
            let hasExtension = fileType.extensions.contains(where: { filename.hasSuffix($0) })
            NSLog("🔍 DEBUG: Pattern matching for \(fileType.name): patterns=\(patterns), hasPattern=\(hasPattern), hasExtension=\(hasExtension)")
            return hasPattern && hasExtension

        case .byExtensionExcludingPattern:
            // Match by extension but exclude certain patterns (e.g., media excluding screenshots)
            let hasExtension = fileType.extensions.contains(where: { filename.hasSuffix($0) })
            let excludePatterns = getExcludePatterns(for: fileType)
            let hasExcludedPattern = excludePatterns.contains(where: { filename.contains($0.lowercased()) })
            NSLog("🔍 DEBUG: Extension excluding pattern for \(fileType.name): hasExtension=\(hasExtension), hasExcludedPattern=\(hasExcludedPattern)")
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
        
        if let savedOrgMode = UserDefaults.standard.string(forKey: "organizationMode"),
           let orgMode = OrganizationMode(rawValue: savedOrgMode) {
            self.organizationMode = orgMode
        }
        
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
    }
    
    private func savePreferences() {
        UserDefaults.standard.set(schedule.rawValue, forKey: "schedule")
        UserDefaults.standard.set(organizationMode.rawValue, forKey: "organizationMode")
        UserDefaults.standard.set(sourceFolder, forKey: "sourceFolder")
        UserDefaults.standard.set(destinationFolder, forKey: "destinationFolder")
        UserDefaults.standard.set(lastRun, forKey: "lastRun")
        UserDefaults.standard.set(dailyCleaningHour, forKey: "dailyCleaningHour")
        UserDefaults.standard.set(dailyCleaningMinute, forKey: "dailyCleaningMinute")
        
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
        NSLog("🔍 DEBUG: Ensuring real folder access (not sandbox paths)")

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
                .appendingPathComponent("Archive")
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

        NSLog("🔍 DEBUG: Final paths:")
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
    private func ensureDocumentsAccess() {
        // Try to access the real Documents folder first
        let realDocuments = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
        let archiveFolder = realDocuments.appendingPathComponent("Archive")

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
                self?.destinationFolder = url.appendingPathComponent("Archive")
                self?.saveDocumentsBookmark(for: url)
            }
        }
    }

    private func saveDocumentsBookmark(for url: URL) {
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
                let archiveURL = url.appendingPathComponent("Archive")
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