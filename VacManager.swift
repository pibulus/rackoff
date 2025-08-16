import Foundation
import SwiftUI
import UserNotifications

enum Schedule: String, CaseIterable {
    case manual = "Manual"
    case onLaunch = "On Launch"
    case daily = "Daily"
}

enum OrganizationMode: String, CaseIterable {
    case quickArchive = "Quick Archive"
    case sortByType = "Sort by Type"
    case smartClean = "Smart Clean"
}

enum FileDestination: String, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case typeFolder = "Type Folder"
    case skip = "Skip"
}

class FileType: Identifiable, ObservableObject {
    let id = UUID()
    let name: String
    let extensions: [String]
    let icon: String
    let patterns: [String]
    @Published var isEnabled: Bool
    @Published var destination: FileDestination
    
    init(name: String, extensions: [String], icon: String, patterns: [String], isEnabled: Bool = false, destination: FileDestination = .daily) {
        self.name = name
        self.extensions = extensions
        self.icon = icon
        self.patterns = patterns
        self.isEnabled = isEnabled
        self.destination = destination
    }
}

@MainActor
class VacManager: ObservableObject {
    @Published var fileTypes: [FileType] = [
        FileType(
            name: "Screenshots",
            extensions: [".jpg", ".png", ".jpeg"],
            icon: "camera.viewfinder",
            patterns: ["screenshot", "Screenshot", "Screen Shot"],
            isEnabled: true,
            destination: .daily
        ),
        FileType(
            name: "PDFs",
            extensions: [".pdf"],
            icon: "doc.fill",
            patterns: ["*.pdf"],
            isEnabled: false,
            destination: .typeFolder
        ),
        FileType(
            name: "Images",
            extensions: [".jpg", ".jpeg", ".png", ".gif", ".webp", ".heic"],
            icon: "photo",
            patterns: ["*.jpg", "*.jpeg", "*.png", "*.gif", "*.webp", "*.heic"],
            isEnabled: false,
            destination: .typeFolder
        ),
        FileType(
            name: "Downloads",
            extensions: [".dmg", ".zip", ".pkg"],
            icon: "arrow.down.circle",
            patterns: ["*.dmg", "*.zip", "*.pkg"],
            isEnabled: false,
            destination: .typeFolder
        ),
        FileType(
            name: "Documents",
            extensions: [".doc", ".docx", ".txt", ".rtf"],
            icon: "doc.text",
            patterns: ["*.doc", "*.docx", "*.txt", "*.rtf"],
            isEnabled: false,
            destination: .typeFolder
        )
    ]
    
    @Published var sourceFolder: URL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
    @Published var destinationFolder: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Archive")
    @Published var schedule: Schedule = .manual
    @Published var organizationMode: OrganizationMode = .quickArchive
    @Published var lastRun: Date?
    
    init() {
        loadPreferences()
        
        // Create archive folder if needed
        try? FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
        
        // Request notification permissions
        requestNotificationPermissions()
        
        // Check if should run on launch
        if schedule == .onLaunch {
            Task {
                await vacuum()
            }
        }
    }
    
    func toggleFileType(_ fileType: FileType, enabled: Bool) {
        if let index = fileTypes.firstIndex(where: { $0.id == fileType.id }) {
            fileTypes[index].isEnabled = enabled
            savePreferences()
        }
    }
    
    func vacuum() async {
        var movedCount = 0
        
        // Process each enabled file type
        for fileType in fileTypes.filter({ $0.isEnabled }) {
            let files = findFiles(ofType: fileType)
            
            for file in files {
                let fileName = file.lastPathComponent
                let destinationFolder = getDestinationFolder(for: fileType)
                
                // Create destination folder if it doesn't exist
                try? FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
                
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
                    } while FileManager.default.fileExists(atPath: destination.path)
                }
                
                do {
                    try FileManager.default.moveItem(at: file, to: destination)
                    movedCount += 1
                } catch {
                    print("Failed to move \(file.lastPathComponent): \(error)")
                }
            }
        }
        
        // Update last run
        lastRun = Date()
        savePreferences()
        
        // Show notification
        showNotification(filesVacuumed: movedCount)
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
                    // Special handling for screenshots
                    if filename.contains("screenshot") || filename.contains("screen shot") {
                        if fileType.extensions.contains(where: { filename.hasSuffix($0) }) {
                            results.append(item)
                        }
                    }
                } else {
                    // General file type matching
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
    
    private func showNotification(filesVacuumed count: Int) {
        let content = UNMutableNotificationContent()
        content.title = "RackOff Complete"
        content.body = count > 0 
            ? "Racked off \(count) file\(count == 1 ? "" : "s") to archive"
            : "Desktop already clean"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "vacuum-complete",
            content: content,
            trigger: nil // Show immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to show notification: \(error)")
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
        for fileType in fileTypes {
            let enabledKey = "fileType_\(fileType.name)"
            if UserDefaults.standard.object(forKey: enabledKey) != nil {
                fileType.isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
            }
            
            let destinationKey = "fileTypeDestination_\(fileType.name)"
            if let savedDestination = UserDefaults.standard.string(forKey: destinationKey),
               let destination = FileDestination(rawValue: savedDestination) {
                fileType.destination = destination
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
}