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
    
    init(name: String, extensions: [String], icon: String, isEnabled: Bool = false, destination: FileDestination = .daily, customDestination: URL? = nil) {
        self.name = name
        self.extensions = extensions
        self.icon = icon
        self.isEnabled = isEnabled
        self.destination = destination
        self.customDestination = customDestination
    }
}

struct UndoOperation {
    let source: URL
    let destination: URL
    let timestamp: Date
}

@MainActor
class VacManager: ObservableObject {
    @Published var fileTypes: [FileType] = [
        FileType(
            name: "Screenshots",
            extensions: [".jpg", ".png", ".jpeg"],
            icon: "camera.viewfinder",
            isEnabled: true,
            destination: .daily
        ),
        FileType(
            name: "Documents",
            extensions: [".pdf", ".doc", ".docx", ".txt", ".rtf", ".pages", ".numbers", ".key"],
            icon: "doc.text",
            isEnabled: false,
            destination: .typeFolder
        ),
        FileType(
            name: "Media",
            extensions: [".jpg", ".jpeg", ".png", ".gif", ".webp", ".heic", ".mp4", ".mov", ".avi"],
            icon: "photo",
            isEnabled: false,
            destination: .typeFolder
        ),
        FileType(
            name: "Archives",
            extensions: [".zip", ".dmg", ".pkg", ".csv", ".json", ".xml", ".log"],
            icon: "archivebox",
            isEnabled: false,
            destination: .typeFolder
        )
    ]
    
    @Published var sourceFolder: URL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Desktop")
    @Published var destinationFolder: URL = (FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")).appendingPathComponent("Archive")
    @Published var schedule: Schedule = .manual
    @Published var organizationMode: OrganizationMode = .quickArchive
    @Published var lastRun: Date?
    @Published var canUndo: Bool = false
    @Published var isProcessing: Bool = false
    @Published var currentProgress: (current: Int, total: Int) = (0, 0)
    
    private var lastOperation: [UndoOperation] = []
    private var saveTimer: Timer?
    private weak var scheduleTimer: Timer?
    
    init() {
        loadPreferences()
        
        // Create archive folder if needed
        try? FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
        
        // Request notification permissions
        requestNotificationPermissions()
        
        // Setup scheduling
        setupScheduling()
    }
    
    deinit {
        // Clean up timers to prevent memory leaks
        saveTimer?.invalidate()
        saveTimer = nil
        scheduleTimer?.invalidate()
        scheduleTimer = nil
    }
    
    private func setupScheduling() {
        // Cancel existing schedule timer
        scheduleTimer?.invalidate()
        
        switch schedule {
        case .manual:
            // No automatic scheduling
            break
            
        case .onLaunch:
            // Run immediately on launch
            Task {
                _ = await vacuum()
            }
            
        case .daily:
            // Schedule daily at 9 AM
            scheduleDailyVacuum()
        }
    }
    
    private func scheduleDailyVacuum() {
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        dateComponents.hour = 9
        dateComponents.minute = 0
        dateComponents.second = 0
        
        guard let targetDate = calendar.date(from: dateComponents) else { return }
        
        // If it's already past 9 AM today, schedule for tomorrow
        let now = Date()
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: targetDate) else { return }
        let scheduledDate = targetDate > now ? targetDate : tomorrow
        
        let timeInterval = scheduledDate.timeIntervalSince(now)
        
        // Schedule the timer
        scheduleTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { _ in
            Task { @MainActor in
                _ = await self.vacuum()
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
    
    func vacuum() async -> (movedCount: Int, errors: [String]) {
        isProcessing = true
        defer { isProcessing = false }
        
        var movedCount = 0
        var errors: [String] = []
        var newUndoOperations: [UndoOperation] = []
        
        // First, count total files to move
        var totalFiles = 0
        for fileType in fileTypes.filter({ $0.isEnabled }) {
            totalFiles += findFiles(ofType: fileType).count
        }
        
        currentProgress = (0, totalFiles)
        
        // Process each enabled file type
        for fileType in fileTypes.filter({ $0.isEnabled }) {
            let files = findFiles(ofType: fileType)
            
            for file in files {
                // Update progress
                currentProgress.current += 1
                
                // Allow UI to update for large operations
                if currentProgress.current % 10 == 0 {
                    await Task.yield()
                }
                
                let fileName = file.lastPathComponent
                let destinationFolder = getDestinationFolder(for: fileType)
                
                // Create destination folder if it doesn't exist
                do {
                    try FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
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
                
                do {
                    try FileManager.default.moveItem(at: file, to: destination)
                    movedCount += 1
                    
                    // Track for undo
                    newUndoOperations.append(UndoOperation(
                        source: file,
                        destination: destination,
                        timestamp: Date()
                    ))
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
        
        // Update last run and show notification
        lastRun = Date()
        savePreferences()
        showNotification(filesVacuumed: movedCount, errors: errors)
        
        currentProgress = (0, 0)
        return (movedCount, errors)
    }
    
    private func getDestinationFolder(for fileType: FileType) -> URL {
        switch organizationMode {
        case .quickArchive:
            // Everything goes to daily folders (current behavior)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            return destinationFolder.appendingPathComponent(dateFormatter.string(from: Date()))
            
        case .sortByType:
            // Everything goes to type folders
            return destinationFolder.appendingPathComponent(fileType.name)
            
        case .smartClean:
            // Use per-file-type destination settings
            switch fileType.destination {
            case .daily:
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                return destinationFolder.appendingPathComponent(dateFormatter.string(from: Date()))
                
            case .weekly:
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-'W'ww"
                return destinationFolder.appendingPathComponent(dateFormatter.string(from: Date()))
                
            case .monthly:
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM"
                return destinationFolder.appendingPathComponent(dateFormatter.string(from: Date()))
                
            case .typeFolder:
                return destinationFolder.appendingPathComponent(fileType.name)
                
            case .custom:
                // Use custom destination if set, otherwise fall back to type folder
                return fileType.customDestination ?? destinationFolder.appendingPathComponent(fileType.name)
                
            case .skip:
                // This case shouldn't happen since we filter enabled file types
                // But return a safe default
                return destinationFolder.appendingPathComponent(fileType.name)
            }
        }
    }
    
    private func findFiles(ofType fileType: FileType) -> [URL] {
        var results: [URL] = []
        let fileManager = FileManager.default
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: sourceFolder, includingPropertiesForKeys: nil)
            
            for item in contents {
                let filename = item.lastPathComponent.lowercased()
                
                // Check if it matches any pattern
                if fileType.name == "Screenshots" {
                    // Special handling for screenshots - filename patterns
                    if filename.contains("screenshot") || filename.contains("screen shot") {
                        if fileType.extensions.contains(where: { filename.hasSuffix($0) }) {
                            results.append(item)
                        }
                    }
                } else if fileType.name == "Media" {
                    // Media files - exclude screenshots from general image matching
                    if fileType.extensions.contains(where: { filename.hasSuffix($0) }) {
                        // Make sure it's not a screenshot
                        if !(filename.contains("screenshot") || filename.contains("screen shot")) {
                            results.append(item)
                        }
                    }
                } else {
                    // General file type matching for Documents and Archives
                    if fileType.extensions.contains(where: { filename.hasSuffix($0) }) {
                        results.append(item)
                    }
                }
            }
        } catch {
            print("Error reading directory: \(error)")
        }
        
        return results
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    private func showNotification(filesVacuumed count: Int, errors: [String] = []) {
        let content = UNMutableNotificationContent()
        content.title = "RackOff Complete"
        
        if !errors.isEmpty {
            content.body = "Moved \(count) file\(count == 1 ? "" : "s") with \(errors.count) error\(errors.count == 1 ? "" : "s")"
            content.subtitle = "Some files couldn't be moved"
        } else if count > 0 {
            content.body = "Racked off \(count) file\(count == 1 ? "" : "s") to archive"
        } else {
            content.body = "Desktop already clean"
        }
        
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString, // Unique ID to allow multiple notifications
            content: content,
            trigger: nil // Show immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to show notification: \(error)")
            }
        }
    }
    
    private func showUndoNotification(filesRestored count: Int, errors: [String] = []) {
        let content = UNMutableNotificationContent()
        content.title = "Undo Complete"
        
        if !errors.isEmpty {
            content.body = "Restored \(count) file\(count == 1 ? "" : "s") with \(errors.count) error\(errors.count == 1 ? "" : "s")"
            content.subtitle = "Some files couldn't be restored"
        } else if count > 0 {
            content.body = "Restored \(count) file\(count == 1 ? "" : "s") to desktop"
        } else {
            content.body = "Nothing to undo"
        }
        
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to show undo notification: \(error)")
            }
        }
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
        
        if let sourceURL = UserDefaults.standard.url(forKey: "sourceFolder") {
            self.sourceFolder = sourceURL
        }
        
        if let destURL = UserDefaults.standard.url(forKey: "destinationFolder") {
            self.destinationFolder = destURL
        }
        
        if let lastRunDate = UserDefaults.standard.object(forKey: "lastRun") as? Date {
            self.lastRun = lastRunDate
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
        }
    }
    
    private func savePreferences() {
        UserDefaults.standard.set(schedule.rawValue, forKey: "schedule")
        UserDefaults.standard.set(organizationMode.rawValue, forKey: "organizationMode")
        UserDefaults.standard.set(sourceFolder, forKey: "sourceFolder")
        UserDefaults.standard.set(destinationFolder, forKey: "destinationFolder")
        UserDefaults.standard.set(lastRun, forKey: "lastRun")
        
        // Save file type preferences
        for fileType in fileTypes {
            let enabledKey = "fileType_\(fileType.name)"
            UserDefaults.standard.set(fileType.isEnabled, forKey: enabledKey)
            
            let destinationKey = "fileTypeDestination_\(fileType.name)"
            UserDefaults.standard.set(fileType.destination.rawValue, forKey: destinationKey)
        }
    }
    
    private func debouncedSave() {
        // Cancel existing timer
        saveTimer?.invalidate()
        
        // Start new timer - save after 500ms of inactivity
        saveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            Task { @MainActor in
                self.savePreferences()
            }
        }
    }
}