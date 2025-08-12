import SwiftUI

struct ContentView: View {
    @StateObject private var vacManager = VacManager()
    @State private var showingFolderPicker = false
    @State private var isVacuuming = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "archivebox.fill")
                    .font(.largeTitle)
                    .foregroundColor(.accentColor)
                Text("DeskVac")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)
            
            // File Types Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Vacuum These Files")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                ForEach(vacManager.fileTypes) { fileType in
                    FileTypeRow(fileType: fileType, vacManager: vacManager)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            // Folders Section  
            VStack(alignment: .leading, spacing: 12) {
                Text("Locations")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "folder")
                    Text("From: \(vacManager.sourceFolder.lastPathComponent)")
                        .lineLimit(1)
                    Spacer()
                    Button("Change") {
                        pickFolder(isSource: true)
                    }
                    .buttonStyle(.bordered)
                }
                
                HStack {
                    Image(systemName: "archivebox")
                    Text("To: \(vacManager.destinationFolder.lastPathComponent)")
                        .lineLimit(1)
                    Spacer()
                    Button("Change") {
                        pickFolder(isSource: false)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            // Schedule Section
            Picker("Run", selection: $vacManager.schedule) {
                Text("Manual").tag(Schedule.manual)
                Text("On Launch").tag(Schedule.onLaunch)
                Text("Daily").tag(Schedule.daily)
            }
            .pickerStyle(.segmented)
            
            Spacer()
            
            // Action Button
            Button(action: performVacuum) {
                if isVacuuming {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 20, height: 20)
                } else {
                    Label("Vacuum Now", systemImage: "sparkles")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isVacuuming)
            
            // Status
            if let lastRun = vacManager.lastRun {
                Text("Last run: \(lastRun, formatter: dateFormatter)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 360, height: 480)
    }
    
    func pickFolder(isSource: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            if isSource {
                vacManager.sourceFolder = url
            } else {
                vacManager.destinationFolder = url
            }
        }
    }
    
    func performVacuum() {
        isVacuuming = true
        
        Task {
            await vacManager.vacuum()
            
            await MainActor.run {
                isVacuuming = false
            }
        }
    }
    
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
}

struct FileTypeRow: View {
    let fileType: FileType
    @ObservedObject var vacManager: VacManager
    
    var body: some View {
        HStack {
            Image(systemName: fileType.icon)
                .foregroundColor(fileType.isEnabled ? .accentColor : .gray)
            
            VStack(alignment: .leading) {
                Text(fileType.name)
                    .font(.system(.body, design: .rounded))
                Text(fileType.extensions.joined(separator: ", "))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { fileType.isEnabled },
                set: { vacManager.toggleFileType(fileType, enabled: $0) }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}