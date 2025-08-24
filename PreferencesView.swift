import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var vacManager: VacManager
    @State private var selectedTab = "folders"
    
    var body: some View {
        TabView(selection: $selectedTab) {
            FoldersTab()
                .tabItem {
                    Label("Folders", systemImage: "folder")
                }
                .tag("folders")
            
            ExtensionsTab()
                .tabItem {
                    Label("Extensions", systemImage: "doc.text")
                }
                .tag("extensions")
            
            ScheduleTab()
                .tabItem {
                    Label("Schedule", systemImage: "clock")
                }
                .tag("schedule")
        }
        .padding()
        .frame(width: 600, height: 500)
    }
}

struct ScheduleTab: View {
    @EnvironmentObject var vacManager: VacManager
    @State private var selectedHour: Int = 9
    @State private var selectedMinute: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Cleaning Schedule")
                .font(.headline)
            
            Picker("Schedule", selection: $vacManager.schedule) {
                Text("Manual").tag(Schedule.manual)
                Text("On Launch").tag(Schedule.onLaunch)
                Text("Daily").tag(Schedule.daily)
            }
            .pickerStyle(.segmented)
            .onChange(of: vacManager.schedule) { newValue in
                vacManager.updateSchedule(newValue)
            }
            
            if vacManager.schedule == .daily {
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Daily Cleaning Time")
                        .font(.headline)
                    
                    Text("Perfect for night owls and early birds alike")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 20) {
                        VStack(alignment: .leading) {
                            Text("Hour")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Picker("Hour", selection: $selectedHour) {
                                ForEach(0..<24) { hour in
                                    Text(String(format: "%02d", hour))
                                        .tag(hour)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 80)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Minute")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Picker("Minute", selection: $selectedMinute) {
                                ForEach([0, 15, 30, 45], id: \.self) { minute in
                                    Text(String(format: "%02d", minute))
                                        .tag(minute)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 80)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Next clean:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(nextCleaningTime)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.primary)
                        }
                    }
                    
                    Button("Update Time") {
                        vacManager.updateDailyCleaningTime(hour: selectedHour, minute: selectedMinute)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            }
            
            if let lastRun = vacManager.lastRun {
                Divider()
                
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.secondary)
                    Text("Last cleaned: \(lastRun.formatted())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            selectedHour = vacManager.dailyCleaningHour
            selectedMinute = vacManager.dailyCleaningMinute
        }
    }
    
    var nextCleaningTime: String {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = selectedHour
        components.minute = selectedMinute
        
        guard let targetDate = calendar.date(from: components) else { return "Unknown" }
        
        let now = Date()
        let scheduledDate = targetDate > now ? targetDate : calendar.date(byAdding: .day, value: 1, to: targetDate) ?? targetDate
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d 'at' HH:mm"
        return formatter.string(from: scheduledDate)
    }
}

struct FoldersTab: View {
    @EnvironmentObject var vacManager: VacManager
    @State private var showingFolderPicker = false
    @State private var pickerFileType: FileType?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Archive Location")
                .font(.headline)
            
            HStack {
                Text(vacManager.destinationFolder.path)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
                
                Button("Choose...") {
                    selectArchiveFolder()
                }
            }
            
            Divider()
            
            Text("Custom Destinations")
                .font(.headline)
            
            ForEach(vacManager.fileTypes) { fileType in
                HStack {
                    Image(systemName: fileType.icon)
                        .frame(width: 20)
                    Text(fileType.name)
                        .frame(width: 100, alignment: .leading)
                    
                    if fileType.destination == .custom, let customDest = fileType.customDestination {
                        Text(customDest.lastPathComponent)
                            .truncationMode(.middle)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Default")
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Set Custom") {
                        pickerFileType = fileType
                        selectCustomFolder(for: fileType)
                    }
                    .buttonStyle(.bordered)
                    
                    if fileType.customDestination != nil {
                        Button("Clear") {
                            vacManager.updateFileTypeCustomDestination(fileType, url: nil)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.red)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Spacer()
        }
        .padding()
    }
    
    func selectArchiveFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Archive Folder"
        
        if panel.runModal() == .OK, let url = panel.url {
            vacManager.updateDestinationFolder(url)
        }
    }
    
    func selectCustomFolder(for fileType: FileType) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder for \(fileType.name)"
        
        if panel.runModal() == .OK, let url = panel.url {
            vacManager.updateFileTypeCustomDestination(fileType, url: url)
        }
    }
}

struct ExtensionsTab: View {
    @EnvironmentObject var vacManager: VacManager
    @State private var editingFileType: FileType?
    @State private var extensionText = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("File Extensions")
                .font(.headline)
            
            Text("Customize which file extensions belong to each category")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(vacManager.fileTypes) { fileType in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: fileType.icon)
                                Text(fileType.name)
                                    .font(.system(size: 14, weight: .medium))
                                Spacer()
                                Button(editingFileType?.id == fileType.id ? "Done" : "Edit") {
                                    if editingFileType?.id == fileType.id {
                                        saveExtensions(for: fileType)
                                        editingFileType = nil
                                    } else {
                                        editingFileType = fileType
                                        extensionText = fileType.extensions.joined(separator: ", ")
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            if editingFileType?.id == fileType.id {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Enter extensions separated by commas (e.g., .jpg, .png, .gif)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    TextEditor(text: $extensionText)
                                        .frame(height: 60)
                                        .padding(4)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(6)
                                        .font(.system(.body, design: .monospaced))
                                }
                                .padding(.leading, 28)
                            } else {
                                Text(fileType.extensions.joined(separator: ", "))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 28)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    func saveExtensions(for fileType: FileType) {
        let extensions = extensionText
            .split(separator: ",")
            .map { ext in
                let trimmed = ext.trimmingCharacters(in: .whitespaces)
                return trimmed.hasPrefix(".") ? trimmed : ".\(trimmed)"
            }
            .filter { !$0.isEmpty }
        
        vacManager.updateFileTypeExtensions(fileType, extensions: extensions)
    }
}