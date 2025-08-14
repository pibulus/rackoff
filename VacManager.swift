import Foundation
import SwiftUI

enum Schedule: String, CaseIterable {
    case manual = "Manual"
    case onLaunch = "On Launch"
    case daily = "Daily"
}

class FileType: Identifiable, ObservableObject {
    let id = UUID()
    let name: String
    let extensions: [String]
    let icon: String
    let patterns: [String]
    @Published var isEnabled: Bool
    
    init(name: String, extensions: [String], icon: String, patterns: [String], isEnabled: Bool = false) {
        self.name = name
        self.extensions = extensions
        self.icon = icon
        self.patterns = patterns
        self.isEnabled = isEnabled
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
            isEnabled: true
        ),
        FileType(
            name: "PDFs",
            extensions: [".pdf"],
            icon: "doc.fill",
            patterns: ["*.pdf"],
            isEnabled: false
        ),
        FileType(
            name: "Images",
            extensions: [".jpg", ".jpeg", ".png", ".gif", ".webp", ".heic"],
            icon: "photo",
            patterns: ["*.jpg", "*.jpeg", "*.png", "*.gif", "*.webp", "*.heic"],
            isEnabled: false
        ),
        FileType(
            name: "Downloads",
            extensions: [".dmg", ".zip", ".pkg"],
            icon: "arrow.down.circle",
            patterns: ["*.dmg", "*.zip", "*.pkg"],
            isEnabled: false
        ),
        FileType(
            name: "Documents",
            extensions: [".doc", ".docx", ".txt", ".rtf"],
            icon: "doc.text",
            patterns: ["*.doc", "*.docx", "*.txt", "*.rtf"],
            isEnabled: false
        )
    ]
    
    @Published var sourceFolder: URL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
    @Published var destinationFolder: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Archive")
    @Published var schedule: Schedule = .manual
    @Published var lastRun: Date?
    
    init() {
        loadPreferences()
        
        // Create archive folder if needed
        try? FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
        
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
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayFolder = destinationFolder.appendingPathComponent(dateFormatter.string(from: Date()))
        
        // Create today's folder
        try? FileManager.default.createDirectory(at: todayFolder, withIntermediateDirectories: true)
        
        var movedCount = 0
        
        // Process each enabled file type
        for fileType in fileTypes.filter({ $0.isEnabled }) {
            let files = findFiles(ofType: fileType)
            
            for file in files {
                let fileName = file.lastPathComponent
                var destination = todayFolder.appendingPathComponent(fileName)
                
                // If file already exists in destination, add a number suffix
                if FileManager.default.fileExists(atPath: destination.path) {
                    let nameWithoutExtension = file.deletingPathExtension().lastPathComponent
                    let fileExtension = file.pathExtension
                    var counter = 2
                    
                    repeat {
                        let newName = "\(nameWithoutExtension) \(counter).\(fileExtension)"
                        destination = todayFolder.appendingPathComponent(newName)
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
    
    private func showNotification(filesVacuumed count: Int) {
        let notification = NSUserNotification()
        notification.title = "DeskVac Complete"
        notification.informativeText = count > 0 
            ? "Vacuumed \(count) file\(count == 1 ? "" : "s") to archive"
            : "Desktop already clean"
        notification.soundName = NSUserNotificationDefaultSoundName
        
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    private func loadPreferences() {
        // Load from UserDefaults
        if let savedSchedule = UserDefaults.standard.string(forKey: "schedule"),
           let schedule = Schedule(rawValue: savedSchedule) {
            self.schedule = schedule
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
            let key = "fileType_\(fileType.name)"
            if UserDefaults.standard.object(forKey: key) != nil {
                fileType.isEnabled = UserDefaults.standard.bool(forKey: key)
            }
        }
    }
    
    private func savePreferences() {
        UserDefaults.standard.set(schedule.rawValue, forKey: "schedule")
        UserDefaults.standard.set(sourceFolder, forKey: "sourceFolder")
        UserDefaults.standard.set(destinationFolder, forKey: "destinationFolder")
        UserDefaults.standard.set(lastRun, forKey: "lastRun")
        
        // Save file type preferences
        for fileType in fileTypes {
            let key = "fileType_\(fileType.name)"
            UserDefaults.standard.set(fileType.isEnabled, forKey: key)
        }
    }
}