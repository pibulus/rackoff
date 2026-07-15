import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var vacManager: VacManager
    @State private var selectedTab = "folders"
    @State private var hoveredTab: String? = nil
    @State private var testSpinning = false
    @State private var showSaveConfirmation = false
    @State private var showUndoSuccess = false
    @State private var undoCount = 0
    
    // Use consistent brand colors
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom tab bar - removed Cleaning tab
            HStack(spacing: 0) {
                TabButton(
                    title: "Folders",
                    icon: "folder.fill",
                    id: "folders",
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
                    title: "About",
                    icon: "info.circle.fill",
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
                    case "folders":
                        FoldersPreferences(vacManager: vacManager)
                    case "schedule":
                        SchedulePreferences(vacManager: vacManager)
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
                            .foregroundStyle(Color(red: 1.0, green: 0.5, blue: 0.3))
                        
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
        .frame(width: RackOffSizes.preferencesWidth, height: RackOffSizes.preferencesHeight)
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
            withAnimation(RackOffAnimations.quickSpring) {
                selectedTab = id
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isSelected ? RackOffColors.sunset : 
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
                            .fill(RackOffColors.sunset)
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

// Schedule preferences tab - Wired to VacManager
struct SchedulePreferences: View {
    @ObservedObject var vacManager: VacManager
    @State private var selectedHour: Int = 9
    @State private var selectedMinute: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            // Automatic cleaning section
            VStack(alignment: .leading, spacing: 16) {
                Label("Automatic Cleaning", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(RackOffColors.sunset)
                
                VStack(spacing: 12) {
                    // Daily clean toggle
                    ScheduleToggleRow(
                        title: "Daily Clean",
                        description: "Automatically clean at scheduled time",
                        icon: "clock.fill",
                        isEnabled: Binding(
                            get: { vacManager.schedule == .daily },
                            set: { enabled in
                                vacManager.updateSchedule(enabled ? .daily : .manual)
                            }
                        ),
                        accentColor: Color(red: 1.0, green: 0.5, blue: 0.3)
                    )
                    
                    // Startup clean toggle
                    ScheduleToggleRow(
                        title: "Clean on Startup",
                        description: "Clean when RackOff launches",
                        icon: "power",
                        isEnabled: Binding(
                            get: { vacManager.schedule == .onLaunch },
                            set: { enabled in
                                vacManager.updateSchedule(enabled ? .onLaunch : .manual)
                            }
                        ),
                        accentColor: Color(red: 0.3, green: 0.5, blue: 1.0)
                    )
                }
            }
            
            // Schedule details (only show if daily is enabled)
            if vacManager.schedule == .daily {
                Divider()
                
                VStack(alignment: .leading, spacing: 16) {
                    Label("Schedule Details", systemImage: "calendar")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(RackOffColors.sunset)
                    
                    // Time picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Clean at this time")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            Image(systemName: "sunrise.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(LinearGradient(
                                    colors: [Color.orange, Color.yellow],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(formattedTime)
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Perfect for a fresh start")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Picker("Hour", selection: $selectedHour) {
                                    ForEach(0..<24, id: \.self) { hour in
                                        Text("\(hour)").tag(hour)
                                    }
                                }
                                .frame(width: 50)
                                .onChange(of: selectedHour) { newValue in
                                    vacManager.updateDailyCleaningTime(hour: newValue, minute: selectedMinute)
                                }
                                
                                Text(":")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Picker("Minute", selection: $selectedMinute) {
                                    ForEach([0, 15, 30, 45], id: \.self) { minute in
                                        Text(String(format: "%02d", minute)).tag(minute)
                                    }
                                }
                                .frame(width: 50)
                                .onChange(of: selectedMinute) { newValue in
                                    vacManager.updateDailyCleaningTime(hour: selectedHour, minute: newValue)
                                }
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        )
                        .onAppear {
                            selectedHour = vacManager.dailyCleaningHour
                            selectedMinute = vacManager.dailyCleaningMinute
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            Divider()
            
            // Stats section
            VStack(alignment: .leading, spacing: 16) {
                Label("Lifetime Stats", systemImage: "chart.bar.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(RackOffColors.sunset)
                
                HStack(spacing: 12) {
                    EnhancedStatBox(
                        icon: "doc.fill",
                        value: formatNumber(vacManager.totalFilesCleaned),
                        label: "Files Cleaned",
                        color: Color(red: 0.3, green: 0.5, blue: 1.0)
                    )
                    
                    EnhancedStatBox(
                        icon: "arrow.down.doc.fill",
                        value: formatBytes(vacManager.totalBytesSaved),
                        label: "Space Saved",
                        color: Color(red: 0.2, green: 0.8, blue: 0.5)
                    )
                    
                    EnhancedStatBox(
                        icon: "calendar",
                        value: formatNumber(vacManager.totalCleanSessions),
                        label: "Clean Sessions",
                        color: Color(red: 0.8, green: 0.3, blue: 0.8)
                    )
                }
            }
            
            Spacer()
        }
    }
    
    private var formattedTime: String {
        let hour = selectedHour
        let minute = selectedMinute
        let ampm = hour < 12 ? "AM" : "PM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return String(format: "%d:%02d %@", displayHour, minute, ampm)
    }
    
    private func formatNumber(_ number: Int) -> String {
        if number >= 1000 {
            let k = Double(number) / 1000.0
            return String(format: "%.1fK", k)
        }
        return "\(number)"
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// Folders preferences tab - Shows what's actually working
struct FoldersPreferences: View {
    @ObservedObject var vacManager: VacManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            // Source folders section
            VStack(alignment: .leading, spacing: 16) {
                Label("Folders to Clean", systemImage: "folder.badge.questionmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(RackOffColors.sunset)
                
                Text("RackOff cleans your Desktop and stashes files safely")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                VStack(spacing: 10) {
                    // Desktop — always active, not toggleable
                    ActiveFolderRow(
                        title: "Desktop",
                        path: "~/Desktop",
                        icon: "menubar.dock.rectangle",
                        accentColor: Color(red: 0.3, green: 0.5, blue: 1.0)
                    )
                    
                    ComingSoonFolderRow(
                        title: "Downloads",
                        path: "~/Downloads",
                        icon: "arrow.down.circle.fill",
                        accentColor: Color(red: 0.2, green: 0.8, blue: 0.5)
                    )
                    
                    ComingSoonFolderRow(
                        title: "Documents",
                        path: "~/Documents",
                        icon: "doc.text.fill",
                        accentColor: Color(red: 0.8, green: 0.3, blue: 0.8)
                    )
                }
            }
            
            Divider()
            
            // Archive destination section
            VStack(alignment: .leading, spacing: 16) {
                Label("Archive Destination", systemImage: "archivebox.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(RackOffColors.sunset)
                
                Text("Where cleaned files are organized")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(LinearGradient(
                            colors: [Color(red: 1.0, green: 0.5, blue: 0.3), 
                                   Color(red: 1.0, green: 0.3, blue: 0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Archive")
                            .font(.system(size: 13, weight: .semibold))
                        Text(vacManager.destinationFolder.path.abbreviatingWithTilde)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Change") {
                        changeArchiveFolder()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                )
            }
            
            Divider()
            
            // Clean organization style section
            VStack(alignment: .leading, spacing: 16) {
                Label("Organization Style", systemImage: "square.grid.2x2.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(RackOffColors.sunset)
                
                Text("Choose how RackOff organizes swept files inside your stash:")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    // Option 1: Date Folders
                    OrgStyleCard(
                        title: "Date Folders",
                        subtitle: "Organized by Year & Month\n(e.g., 2026/07-July/file.png)",
                        icon: "calendar",
                        isSelected: vacManager.organizationMode == .quickArchive,
                        action: {
                            withAnimation(RackOffAnimations.quickSpring) {
                                vacManager.updateOrganizationMode(.quickArchive)
                            }
                        }
                    )
                    
                    // Option 2: Category Folders
                    OrgStyleCard(
                        title: "Category Folders",
                        subtitle: "Organized by File Category\n(e.g., Screenshots/file.png)",
                        icon: "folder.badge.gearshape",
                        isSelected: vacManager.organizationMode == .sortByType,
                        action: {
                            withAnimation(RackOffAnimations.quickSpring) {
                                vacManager.updateOrganizationMode(.sortByType)
                            }
                        }
                    )
                }
            }

            Spacer()
        }
    }

    private func changeArchiveFolder() {
        let panel = NSOpenPanel()
        panel.message = "Select where RackOff should store archived files"
        panel.prompt = "Select Folder"
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.directoryURL = vacManager.destinationFolder
        
        if panel.runModal() == .OK, let url = panel.url {
            vacManager.updateDestinationFolder(url)
        }
    }
}

private extension String {
    var abbreviatingWithTilde: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if hasPrefix(home) {
            return "~" + dropFirst(home.count)
        }
        return self
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
                    .foregroundStyle(RackOffColors.sunset)
                    .rotationEffect(.degrees(testSpinning ? 360 : 0))
                    .animation(testSpinning ? .linear(duration: 2).repeatForever(autoreverses: false) : .default, value: testSpinning)
                    .onTapGesture {
                        testSpinning.toggle()
                    }
                
                Text("RackOff")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(RackOffColors.sunset)
                
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
                                .stroke(RackOffColors.sunset, lineWidth: 1)
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

// New helper components for enhanced preferences

// Active folder row — shows a folder that's always cleaned
struct ActiveFolderRow: View {
    let title: String
    let path: String
    let icon: String
    let accentColor: Color
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(
                    LinearGradient(colors: [accentColor, accentColor.opacity(0.7)],
                                 startPoint: .topLeading,
                                 endPoint: .bottomTrailing))
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                Text(path)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("Active")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(accentColor.opacity(0.12))
                )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? 
                    Color(NSColor.controlBackgroundColor).opacity(0.6) :
                    Color(NSColor.controlBackgroundColor).opacity(0.3))
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// Coming soon folder row (disabled placeholder)
struct ComingSoonFolderRow: View {
    let title: String
    let path: String
    let icon: String
    let accentColor: Color
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(
                    LinearGradient(colors: [Color.gray.opacity(0.4)],
                                 startPoint: .topLeading,
                                 endPoint: .bottomTrailing))
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(path)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("Soon")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.secondary.opacity(0.12))
                )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.3))
        )
        .opacity(0.7)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// Schedule toggle row
struct ScheduleToggleRow: View {
    let title: String
    let description: String
    let icon: String
    @Binding var isEnabled: Bool
    let accentColor: Color
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isEnabled ? accentColor : Color.gray)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isEnabled ? .primary : .secondary)
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isEnabled)
                .toggleStyle(SwitchToggleStyle(tint: accentColor))
                .labelsHidden()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? 
                    Color(NSColor.controlBackgroundColor).opacity(0.6) :
                    Color(NSColor.controlBackgroundColor).opacity(0.3))
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// Enhanced stat box
struct EnhancedStatBox: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [color.opacity(0.2), color.opacity(0.1)],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(LinearGradient(colors: [color, color.opacity(0.7)],
                                                  startPoint: .topLeading,
                                                  endPoint: .bottomTrailing))
                    .scaleEffect(isHovered ? 1.15 : 1.0)
            }
            
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isHovered ? color.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
struct PhilosophyRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(RackOffColors.sunset)
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

// Card for selecting organization style
struct OrgStyleCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    // Decompose complex style expressions to prevent Swift compiler typecheck timeout
    private var circleFill: Color {
        isSelected ? Color.orange.opacity(0.15) : Color.secondary.opacity(0.1)
    }
    
    private var iconColor: LinearGradient {
        isSelected ? RackOffColors.sunset : LinearGradient(colors: [.secondary], startPoint: .leading, endPoint: .trailing)
    }
    
    private var titleColor: Color {
        isSelected ? .primary : .secondary
    }
    
    private var bgFill: Color {
        Color(NSColor.controlBackgroundColor).opacity(isSelected ? 0.5 : 0.15)
    }
    
    private var borderStrokeColor: Color {
        isSelected ? Color(red: 1.0, green: 0.5, blue: 0.3).opacity(0.4) : Color.clear
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(circleFill)
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(iconColor)
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(RackOffColors.sunset)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(titleColor)
                
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.8))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(bgFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderStrokeColor, lineWidth: 2)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isHovered = hovering
            }
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}