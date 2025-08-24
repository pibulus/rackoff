import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var vacManager: VacManager
    @State private var selectedTab = "cleaning"
    @State private var hoveredTab: String? = nil
    @State private var testSpinning = false
    @State private var showSaveConfirmation = false
    @State private var showUndoSuccess = false
    @State private var undoCount = 0
    
    // Color scheme matching main app
    static let accentGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.5, blue: 0.3), 
                Color(red: 1.0, green: 0.3, blue: 0.5)],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom tab bar
            HStack(spacing: 0) {
                TabButton(
                    title: "Cleaning",
                    icon: "sparkles",
                    id: "cleaning",
                    selectedTab: $selectedTab,
                    hoveredTab: $hoveredTab
                )
                
                TabButton(
                    title: "Schedule",
                    icon: "clock.fill",
                    id: "schedule",
                    selectedTab: $selectedTab,
                    hoveredTab: $hoveredTab
                )
                
                TabButton(
                    title: "Folders",
                    icon: "folder.fill",
                    id: "folders",
                    selectedTab: $selectedTab,
                    hoveredTab: $hoveredTab
                )
                
                TabButton(
                    title: "About",
                    icon: "star.fill",
                    id: "about",
                    selectedTab: $selectedTab,
                    hoveredTab: $hoveredTab
                )
            }
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
            
            Divider()
            
            // Tab content
            ScrollView {
                VStack(spacing: 20) {
                    switch selectedTab {
                    case "cleaning":
                        CleaningPreferences(vacManager: vacManager)
                    case "schedule":
                        SchedulePreferences(vacManager: vacManager)
                    case "folders":
                        FoldersPreferences(vacManager: vacManager)
                    case "about":
                        AboutPreferences(testSpinning: $testSpinning)
                    default:
                        EmptyView()
                    }
                }
                .padding(24)
            }
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
            
            // Footer with undo
            if vacManager.canUndo {
                VStack(spacing: 0) {
                    Divider()
                    
                    HStack {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Self.accentGradient)
                        
                        Text("Last clean moved files")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("Undo Last Clean") {
                            Task {
                                let result = await vacManager.undoLastClean()
                                undoCount = result.restoredCount
                                showUndoSuccess = true
                                
                                // Hide after delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    showUndoSuccess = false
                                }
                            }
                        }
                        .buttonStyle(GradientButtonStyle())
                        
                        if showUndoSuccess {
                            Text("✓ Restored \(undoCount) files")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.green)
                                .transition(.opacity.combined(with: .scale))
                        }
                    }
                    .padding(16)
                    .background(Color(NSColor.windowBackgroundColor))
                }
            }
        }
        .frame(width: 600, height: 500)
    }
}

// Custom tab button
struct TabButton: View {
    let title: String
    let icon: String
    let id: String
    @Binding var selectedTab: String
    @Binding var hoveredTab: String?
    
    var isSelected: Bool { selectedTab == id }
    var isHovered: Bool { hoveredTab == id }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = id
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isSelected ? PreferencesView.accentGradient : 
                                   LinearGradient(colors: [Color.secondary], startPoint: .leading, endPoint: .trailing))
                    .scaleEffect(isHovered ? 1.1 : 1.0)
                
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                VStack(spacing: 0) {
                    Spacer()
                    if isSelected {
                        Rectangle()
                            .fill(PreferencesView.accentGradient)
                            .frame(height: 3)
                            .transition(.opacity.combined(with: .scale))
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                hoveredTab = hovering ? id : nil
            }
        }
    }
}

// Cleaning preferences tab
struct CleaningPreferences: View {
    @ObservedObject var vacManager: VacManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Organization mode
            VStack(alignment: .leading, spacing: 12) {
                Label("Organization Style", systemImage: "square.grid.3x3")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PreferencesView.accentGradient)
                
                VStack(alignment: .leading, spacing: 10) {
                    OrganizationModeRow(
                        mode: .quickArchive,
                        title: "Quick Archive",
                        description: "Everything goes to dated folders. Simple.",
                        vacManager: vacManager
                    )
                    
                    OrganizationModeRow(
                        mode: .sortByType,
                        title: "Sort by Type",
                        description: "Screenshots here, documents there. Organized.",
                        vacManager: vacManager
                    )
                    
                    OrganizationModeRow(
                        mode: .smartClean,
                        title: "Smart Clean",
                        description: "You decide where each type goes. Full control.",
                        vacManager: vacManager
                    )
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            
            // File types to clean
            VStack(alignment: .leading, spacing: 12) {
                Label("What to Clean", systemImage: "doc.on.doc")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PreferencesView.accentGradient)
                
                Text("Choose which file types RackOff should handle")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                LazyVStack(spacing: 8) {
                    ForEach(vacManager.fileTypes) { fileType in
                        FileTypePreferenceRow(
                            fileType: fileType,
                            vacManager: vacManager
                        )
                    }
                }
            }
            
            Spacer()
        }
    }
}

// Schedule preferences tab
struct SchedulePreferences: View {
    @ObservedObject var vacManager: VacManager
    @State private var selectedTime = 9
    @State private var enableDaily = UserDefaults.standard.bool(forKey: "enableDailyClean")
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Daily cleaning toggle
            VStack(alignment: .leading, spacing: 16) {
                Label("Automatic Cleaning", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PreferencesView.accentGradient)
                
                HStack {
                    Toggle(isOn: $enableDaily) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Clean desktop daily")
                                .font(.system(size: 13, weight: .medium))
                            Text("Runs automatically at your chosen time")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: enableDaily) { _ in
                        UserDefaults.standard.set(enableDaily, forKey: "enableDailyClean")
                        // Timer setup happens in VacManager
                    }
                    .toggleStyle(SwitchToggleStyle(tint: Color(red: 1.0, green: 0.5, blue: 0.3)))
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            
            // Time picker (only show if enabled)
            if enableDaily {
                VStack(alignment: .leading, spacing: 12) {
                    Label("When to Clean", systemImage: "clock")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PreferencesView.accentGradient)
                    
                    HStack(spacing: 16) {
                        Image(systemName: "sunrise.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.orange.opacity(0.8))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("9:00 AM")
                                .font(.system(size: 16, weight: .semibold))
                            Text("The perfect time for a fresh start")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("(Not configurable yet)")
                            .font(.system(size: 10))
                            .foregroundColor(Color.secondary.opacity(0.5))
                    }
                    .padding(16)
                    .background(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.05), Color.yellow.opacity(0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                    )
                    .cornerRadius(8)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Stats section
            VStack(alignment: .leading, spacing: 12) {
                Label("Cleaning Stats", systemImage: "chart.bar.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PreferencesView.accentGradient)
                
                HStack(spacing: 16) {
                    StatBox(
                        icon: "doc.fill",
                        value: "0",
                        label: "Files Cleaned"
                    )
                    
                    StatBox(
                        icon: "arrow.down.doc.fill",
                        value: "0 KB",
                        label: "Space Saved"
                    )
                    
                    StatBox(
                        icon: "calendar",
                        value: "0",
                        label: "Sessions"
                    )
                }
            }
            
            Spacer()
        }
    }
    
    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.zeroPadsFractionDigits = true
        return formatter.string(fromByteCount: bytes)
    }
}

// Folders preferences tab
struct FoldersPreferences: View {
    @ObservedObject var vacManager: VacManager
    @State private var customPaths: [String: URL] = [:]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Archive location
            VStack(alignment: .leading, spacing: 12) {
                Label("Archive Location", systemImage: "archivebox.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PreferencesView.accentGradient)
                
                HStack {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.orange)
                    
                    Text("~/Desktop/Archive")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button("Change...") {
                        // TODO: Show folder picker
                    }
                    .buttonStyle(BorderedButtonStyle())
                    .disabled(true) // For now
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                
                Text("This is where RackOff moves your files")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            // Custom destinations (only in Smart Clean mode)
            if vacManager.organizationMode == .smartClean {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Custom Destinations", systemImage: "arrow.triangle.branch")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PreferencesView.accentGradient)
                    
                    Text("Set custom folders for each file type")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    LazyVStack(spacing: 8) {
                        ForEach(vacManager.fileTypes.filter { $0.destination == .custom }) { fileType in
                            CustomDestinationRow(
                                fileType: fileType,
                                vacManager: vacManager
                            )
                        }
                    }
                    
                    if vacManager.fileTypes.filter({ $0.destination == .custom }).isEmpty {
                        Text("No custom destinations set. Right-click a file type and choose 'Custom folder...'")
                            .font(.system(size: 11))
                            .foregroundColor(Color.secondary.opacity(0.5))
                            .padding(.vertical, 20)
                            .frame(maxWidth: .infinity)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(8)
                    }
                }
            }
            
            Spacer()
        }
    }
}

// About tab
struct AboutPreferences: View {
    @Binding var testSpinning: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            // Logo and title
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(PreferencesView.accentGradient)
                    .rotationEffect(.degrees(testSpinning ? 360 : 0))
                    .animation(testSpinning ? .linear(duration: 2).repeatForever(autoreverses: false) : .default, value: testSpinning)
                    .onTapGesture {
                        testSpinning.toggle()
                    }
                
                Text("RackOff")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(PreferencesView.accentGradient)
                
                Text("Version 1.0.0")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            // Tagline
            Text("Desktop cleaning that gets it")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color(NSColor.controlBackgroundColor))
                        .overlay(
                            Capsule()
                                .stroke(PreferencesView.accentGradient, lineWidth: 1)
                        )
                )
            
            // Philosophy
            VStack(spacing: 16) {
                PhilosophyRow(
                    icon: "bolt.fill",
                    text: "One click, no drama"
                )
                
                PhilosophyRow(
                    icon: "heart.fill",
                    text: "Respects your workflow"
                )
                
                PhilosophyRow(
                    icon: "sparkles",
                    text: "Makes desktops happy"
                )
            }
            .padding(20)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(12)
            
            // Links
            HStack(spacing: 20) {
                Link(destination: URL(string: "https://softstack.dev")!) {
                    Label("SoftStack", systemImage: "globe")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(LinkButtonStyle())
                
                Link(destination: URL(string: "https://github.com/pibulus/rackoff")!) {
                    Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(LinkButtonStyle())
            }
            
            Spacer()
            
            // Creator credit
            Text("Made with attitude by Pablo")
                .font(.system(size: 11))
                .foregroundColor(Color.secondary.opacity(0.5))
        }
    }
}

// Helper views
struct OrganizationModeRow: View {
    let mode: OrganizationMode
    let title: String
    let description: String
    @ObservedObject var vacManager: VacManager
    
    var isSelected: Bool { vacManager.organizationMode == mode }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                vacManager.organizationMode = mode
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? PreferencesView.accentGradient : 
                                   LinearGradient(colors: [Color.secondary], startPoint: .leading, endPoint: .trailing))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(10)
            .background(isSelected ? Color(NSColor.controlAccentColor).opacity(0.1) : Color.clear)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color(NSColor.controlAccentColor).opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FileTypePreferenceRow: View {
    let fileType: FileType
    @ObservedObject var vacManager: VacManager
    
    var accentColor: Color {
        switch fileType.name {
        case "Screenshots": return Color(red: 1.0, green: 0.5, blue: 0.3)
        case "Documents": return Color(red: 0.4, green: 0.6, blue: 0.9)
        case "Media": return Color(red: 0.3, green: 0.8, blue: 0.5)
        case "Archives": return Color(red: 0.8, green: 0.4, blue: 0.8)
        default: return Color.accentColor
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: fileType.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(fileType.isEnabled ? accentColor : .secondary)
                .frame(width: 24)
            
            Text(fileType.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(fileType.isEnabled ? .primary : .secondary)
            
            Text("(\(fileType.extensions.joined(separator: ", ")))")
                .font(.system(size: 11))
                .foregroundColor(Color.secondary.opacity(0.5))
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { fileType.isEnabled },
                set: { vacManager.toggleFileType(fileType, enabled: $0) }
            ))
            .toggleStyle(SwitchToggleStyle(tint: accentColor))
            .labelsHidden()
            .scaleEffect(0.8)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
    }
}

struct CustomDestinationRow: View {
    let fileType: FileType
    @ObservedObject var vacManager: VacManager
    
    var body: some View {
        HStack {
            Image(systemName: fileType.icon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Text(fileType.name)
                .font(.system(size: 12, weight: .medium))
            
            Image(systemName: "arrow.right")
                .font(.system(size: 10))
                .foregroundColor(Color.secondary.opacity(0.5))
            
            if let customDest = fileType.customDestination {
                Text(customDest.lastPathComponent)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            } else {
                Text("Not set")
                    .font(.system(size: 12))
                    .foregroundColor(Color.secondary.opacity(0.5))
                    .italic()
            }
            
            Spacer()
            
            Button("Choose...") {
                // TODO: Show folder picker
            }
            .buttonStyle(BorderedButtonStyle())
            .scaleEffect(0.9)
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
    }
}

struct StatBox: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(PreferencesView.accentGradient)
            
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
            
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [Color(red: 1.0, green: 0.5, blue: 0.3).opacity(0.05), 
                        Color(red: 1.0, green: 0.3, blue: 0.5).opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(red: 1.0, green: 0.5, blue: 0.3).opacity(0.15), lineWidth: 1)
        )
        .cornerRadius(8)
    }
}

struct PhilosophyRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(PreferencesView.accentGradient)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

// Button styles
struct GradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                LinearGradient(
                    colors: configuration.isPressed ? 
                        [Color(red: 0.8, green: 0.3, blue: 0.3), Color(red: 0.8, green: 0.4, blue: 0.2)] :
                        [Color(red: 1.0, green: 0.4, blue: 0.4), Color(red: 1.0, green: 0.6, blue: 0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
    }
}

struct LinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? .accentColor.opacity(0.7) : .accentColor)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}