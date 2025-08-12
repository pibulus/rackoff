import SwiftUI

struct ContentView: View {
    @StateObject private var vacManager = VacManager()
    @State private var isVacuuming = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Clean header
            VStack(spacing: 6) {
                Text("RackOff")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text("Clean desk. Clear mind.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
            
            // File types - simple list
            VStack(alignment: .leading, spacing: 0) {
                ForEach(vacManager.fileTypes) { fileType in
                    FileTypeRow(fileType: fileType, vacManager: vacManager)
                    if fileType.id != vacManager.fileTypes.last?.id {
                        Divider()
                            .padding(.leading, 40)
                    }
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            
            Spacer()
            
            // Simple schedule selector
            Picker("", selection: $vacManager.schedule) {
                Text("Manual").tag(Schedule.manual)
                Text("Daily").tag(Schedule.daily)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            
            // Big clean button
            Button(action: performVacuum) {
                HStack {
                    if isVacuuming {
                        ProgressView()
                            .scaleEffect(0.7)
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                    Text(isVacuuming ? "Cleaning..." : "Clean Now")
                        .font(.system(size: 16, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isVacuuming)
        }
        .padding(20)
        .frame(width: 280, height: 420)
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
}

struct FileTypeRow: View {
    let fileType: FileType
    @ObservedObject var vacManager: VacManager
    
    var body: some View {
        HStack {
            Image(systemName: fileType.icon)
                .font(.system(size: 18))
                .foregroundColor(fileType.isEnabled ? .accentColor : .secondary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(fileType.name)
                    .font(.system(size: 13, weight: .medium))
                if fileType.isEnabled {
                    Text(fileType.extensions.prefix(3).joined(separator: ", "))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { fileType.isEnabled },
                set: { vacManager.toggleFileType(fileType, enabled: $0) }
            ))
            .toggleStyle(SwitchToggleStyle())
            .labelsHidden()
            .scaleEffect(0.75)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            vacManager.toggleFileType(fileType, enabled: !fileType.isEnabled)
        }
    }
}