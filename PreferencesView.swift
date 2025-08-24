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

// Cleaning preferences tab - ultra minimal
struct CleaningPreferences: View {
    @ObservedObject var vacManager: VacManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Organization mode section
            VStack(spacing: 16) {
                HStack {
                    Text("Organization Mode")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                HStack(spacing: 12) {
                    ForEach([
                        (OrganizationMode.quickArchive, "Archive", "archivebox", "Everything to dated folders"),
                        (OrganizationMode.sortByType, "Sort", "folder.badge.gearshape", "Organized by type"),
                        (OrganizationMode.smartClean, "Smart", "slider.horizontal.3", "Full control")
                    ], id: \.0) { mode, title, icon, desc in
                        OrganizationModeCard(
                            mode: mode,
                            title: title,
                            icon: icon,
                            description: desc,
                            vacManager: vacManager
                        )
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 20)
            
            // Divider
            Divider()
                .padding(.horizontal, -24)
            
            // File types section
            VStack(spacing: 16) {
                HStack {
                    Text("File Types")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.top, 20)
                
                // File types - vertical list
                VStack(spacing: 10) {
                    ForEach(vacManager.fileTypes) { fileType in
                        CompactFileTypeRow(
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

// Schedule preferences tab - Enhanced
struct SchedulePreferences: View {
    @ObservedObject var vacManager: VacManager
    @State private var selectedTime = 9
    @State private var enableDaily = UserDefaults.standard.bool(forKey: "enableDailyClean")
    @State private var cleanOnStartup = false
    @State private var notifyBeforeClean = true
    @State private var selectedDays = Set<Int>([1, 2, 3, 4, 5]) // Weekdays
    
    let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
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
                        isEnabled: $enableDaily,
                        accentColor: Color(red: 1.0, green: 0.5, blue: 0.3)
                    )
                    
                    // Startup clean toggle
                    ScheduleToggleRow(
                        title: "Clean on Startup",
                        description: "Clean when Mac starts up",
                        icon: "power",
                        isEnabled: $cleanOnStartup,
                        accentColor: Color(red: 0.3, green: 0.5, blue: 1.0)
                    )
                    
                    // Notification toggle
                    ScheduleToggleRow(
                        title: "Notify Before Cleaning",
                        description: "Show alert 5 minutes before auto-clean",
                        icon: "bell.fill",
                        isEnabled: $notifyBeforeClean,
                        accentColor: Color(red: 0.8, green: 0.3, blue: 0.8)
                    )
                }
            }
            
            // Schedule details (only show if daily is enabled)
            if enableDaily {
                Divider()
                
                VStack(alignment: .leading, spacing: 16) {
                    Label("Schedule Details", systemImage: "calendar")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(RackOffColors.sunset)
                    
                    // Days selector
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Clean on these days")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            ForEach(0..<7) { day in
                                DayButton(
                                    day: weekdays[day],
                                    isSelected: selectedDays.contains(day),
                                    action: {
                                        if selectedDays.contains(day) {
                                            selectedDays.remove(day)
                                        } else {
                                            selectedDays.insert(day)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    
                    // Time picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Clean at this time")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 16) {
                            Image(systemName: "sunrise.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(LinearGradient(
                                    colors: [Color.orange, Color.yellow],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("9:00 AM")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Perfect for a fresh start")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("Coming soon")
                                .font(.system(size: 10))
                                .foregroundColor(Color.secondary.opacity(0.5))
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        )
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
                        value: "1,247",
                        label: "Files Cleaned",
                        color: Color(red: 0.3, green: 0.5, blue: 1.0)
                    )
                    
                    EnhancedStatBox(
                        icon: "arrow.down.doc.fill",
                        value: "2.3 GB",
                        label: "Space Saved",
                        color: Color(red: 0.2, green: 0.8, blue: 0.5)
                    )
                    
                    EnhancedStatBox(
                        icon: "calendar",
                        value: "42",
                        label: "Clean Sessions",
                        color: Color(red: 0.8, green: 0.3, blue: 0.8)
                    )
                }
            }
            
            Spacer()
        }
    }
}

// Folders preferences tab - Enhanced with source folders
struct FoldersPreferences: View {
    @ObservedObject var vacManager: VacManager
    @State private var customPaths: [String: URL] = [:]
    @State private var cleanDesktop = true
    @State private var cleanDownloads = true
    @State private var cleanDocuments = false
    @State private var additionalFolders: [URL] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            // Source folders section
            VStack(alignment: .leading, spacing: 16) {
                Label("Folders to Clean", systemImage: "folder.badge.questionmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(RackOffColors.sunset)
                
                Text("Choose which folders RackOff should monitor and clean")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                VStack(spacing: 10) {
                    FolderToggleRow(
                        title: "Desktop",
                        path: "~/Desktop",
                        icon: "menubar.dock.rectangle",
                        isEnabled: $cleanDesktop,
                        accentColor: Color(red: 0.3, green: 0.5, blue: 1.0)
                    )
                    
                    FolderToggleRow(
                        title: "Downloads",
                        path: "~/Downloads",
                        icon: "arrow.down.circle.fill",
                        isEnabled: $cleanDownloads,
                        accentColor: Color(red: 0.2, green: 0.8, blue: 0.5)
                    )
                    
                    FolderToggleRow(
                        title: "Documents",
                        path: "~/Documents",
                        icon: "doc.text.fill",
                        isEnabled: $cleanDocuments,
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
                        Text("~/Desktop/Archive")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Change") {
                        // TODO: Show folder picker
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
            
            // Smart destinations (if in Smart mode)
            if vacManager.organizationMode == .smartClean {
                Divider()
                
                VStack(alignment: .leading, spacing: 16) {
                    Label("Smart Destinations", systemImage: "arrow.triangle.branch")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(RackOffColors.sunset)
                    
                    Text("Custom folders for each file type")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 8) {
                        ForEach(vacManager.fileTypes) { fileType in
                            SmartDestinationRow(
                                fileType: fileType,
                                vacManager: vacManager
                            )
                        }
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

// Helper views
struct OrganizationModeRow: View {
    let mode: OrganizationMode
    let title: String
    let description: String
    @ObservedObject var vacManager: VacManager
    @State private var isHovered = false
    
    var isSelected: Bool { vacManager.organizationMode == mode }
    
    private var modeIcon: String {
        switch mode {
        case .quickArchive: return "archivebox"
        case .sortByType: return "folder.badge.gearshape"
        case .smartClean: return "slider.horizontal.3"
        }
    }
    
    private var backgroundFill: Color {
        if isSelected {
            return Color(red: 1.0, green: 0.5, blue: 0.3).opacity(0.08)
        } else if isHovered {
            return Color(NSColor.controlBackgroundColor).opacity(0.6)
        } else {
            return Color.clear
        }
    }
    
    private var borderStroke: Color {
        isSelected ? Color(red: 1.0, green: 0.5, blue: 0.3).opacity(0.4) : Color.clear
    }
    
    var body: some View {
        Button(action: {
            withAnimation(RackOffAnimations.quickSpring) {
                vacManager.organizationMode = mode
            }
        }) {
            HStack(spacing: 20) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(isSelected ? Color(red: 1.0, green: 0.5, blue: 0.3).opacity(0.15) : Color.clear)
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: modeIcon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isSelected ? Color(red: 1.0, green: 0.5, blue: 0.3) : Color.secondary)
                        .scaleEffect(isHovered ? 1.1 : 1.0)
                }
                
                // Text content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if isHovered || isSelected {
                        Text(description)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(red: 1.0, green: 0.5, blue: 0.3))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 16).fill(backgroundFill))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(borderStroke, lineWidth: 1.5))
            .scaleEffect(isHovered ? 1.01 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

struct SimpleFileTypeRow: View {
    let fileType: FileType
    @ObservedObject var vacManager: VacManager
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: fileType.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(RackOffColors.sunset)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(fileType.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(fileType.extensions.prefix(3).joined(separator: ", ") + (fileType.extensions.count > 3 ? "..." : ""))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { fileType.isEnabled },
                set: { vacManager.toggleFileType(fileType, enabled: $0) }
            ))
            .toggleStyle(SwitchToggleStyle(tint: Color(red: 1.0, green: 0.5, blue: 0.3)))
            .labelsHidden()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}

// New horizontal organization mode card
struct OrganizationModeCard: View {
    let mode: OrganizationMode
    let title: String
    let icon: String
    let description: String
    @ObservedObject var vacManager: VacManager
    @State private var isHovered = false
    
    var isSelected: Bool { vacManager.organizationMode == mode }
    
    var body: some View {
        Button(action: {
            withAnimation(RackOffAnimations.quickSpring) {
                vacManager.organizationMode = mode
            }
        }) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? 
                            LinearGradient(colors: [Color(red: 1.0, green: 0.5, blue: 0.3), 
                                                   Color(red: 1.0, green: 0.3, blue: 0.5)],
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing) :
                            LinearGradient(colors: [Color.gray.opacity(0.1)],
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(isSelected ? .white : .secondary)
                        .scaleEffect(isHovered ? 1.15 : 1.0)
                }
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isSelected ? .primary : .secondary)
                    
                    Text(description)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? 
                        Color(red: 1.0, green: 0.5, blue: 0.3).opacity(0.08) :
                        (isHovered ? Color.gray.opacity(0.05) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? 
                        Color(red: 1.0, green: 0.5, blue: 0.3).opacity(0.3) :
                        Color.clear, lineWidth: 2)
            )
            .scaleEffect(isHovered && !isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// Compact file type row for vertical list
struct CompactFileTypeRow: View {
    let fileType: FileType
    @ObservedObject var vacManager: VacManager
    @State private var isHovered = false
    @State private var toggleScale: CGFloat = 1.0
    
    // Vibrant colors for each file type
    var accentColor: Color {
        switch fileType.name {
        case "Screenshots":
            return Color(red: 1.0, green: 0.5, blue: 0.3)
        case "Documents":
            return Color(red: 0.3, green: 0.5, blue: 1.0)
        case "Media":
            return Color(red: 0.2, green: 0.8, blue: 0.5)
        case "Archives":
            return Color(red: 0.8, green: 0.3, blue: 0.8)
        default:
            return Color.gray
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(fileType.isEnabled ? 
                        LinearGradient(colors: [accentColor, accentColor.opacity(0.7)],
                                     startPoint: .topLeading,
                                     endPoint: .bottomTrailing) :
                        LinearGradient(colors: [Color.gray.opacity(0.2)],
                                     startPoint: .topLeading,
                                     endPoint: .bottomTrailing))
                    .frame(width: 42, height: 42)
                
                Image(systemName: fileType.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .scaleEffect(isHovered ? 1.1 : 1.0)
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 3) {
                Text(fileType.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(fileType.isEnabled ? .primary : .secondary)
                
                Text(fileType.extensions.prefix(4).joined(separator: ", "))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Toggle
            Toggle("", isOn: Binding(
                get: { fileType.isEnabled },
                set: { newValue in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                        toggleScale = 1.3
                    }
                    vacManager.toggleFileType(fileType, enabled: newValue)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            toggleScale = 1.0
                        }
                    }
                }
            ))
            .toggleStyle(SwitchToggleStyle(tint: accentColor))
            .labelsHidden()
            .scaleEffect(toggleScale * 0.9)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? 
                    Color(NSColor.controlBackgroundColor).opacity(0.6) :
                    Color(NSColor.controlBackgroundColor).opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(fileType.isEnabled && isHovered ? 
                            accentColor.opacity(0.3) : 
                            Color.clear, lineWidth: 1.5)
                )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// Enhanced file type card with better colors
struct EnhancedFileTypeCard: View {
    let fileType: FileType
    @ObservedObject var vacManager: VacManager
    @State private var isHovered = false
    
    // Vibrant colors for each file type
    var accentGradient: LinearGradient {
        let colors: [Color]
        switch fileType.name {
        case "Screenshots":
            colors = [Color(red: 1.0, green: 0.5, blue: 0.3), 
                     Color(red: 1.0, green: 0.3, blue: 0.5)]
        case "Documents":
            colors = [Color(red: 0.3, green: 0.5, blue: 1.0), 
                     Color(red: 0.5, green: 0.3, blue: 1.0)]
        case "Media":
            colors = [Color(red: 0.2, green: 0.8, blue: 0.5), 
                     Color(red: 0.3, green: 0.9, blue: 0.4)]
        case "Archives":
            colors = [Color(red: 0.8, green: 0.3, blue: 0.8), 
                     Color(red: 0.9, green: 0.4, blue: 0.6)]
        default:
            colors = [Color.gray]
        }
        return LinearGradient(colors: colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing)
    }
    
    var disabledGradient: LinearGradient {
        LinearGradient(colors: [Color.gray.opacity(0.2)],
                      startPoint: .topLeading,
                      endPoint: .bottomTrailing)
    }
    
    @ViewBuilder
    var iconView: some View {
        ZStack {
            Circle()
                .fill(fileType.isEnabled ? accentGradient : disabledGradient)
                .frame(width: 48, height: 48)
            
            Image(systemName: fileType.icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white)
                .scaleEffect(isHovered ? 1.15 : 1.0)
        }
    }
    
    @ViewBuilder
    var statusIndicator: some View {
        Circle()
            .fill(fileType.isEnabled ? Color.green : Color.gray.opacity(0.3))
            .frame(width: 8, height: 8)
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                vacManager.toggleFileType(fileType, enabled: !fileType.isEnabled)
            }
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    iconView
                    Spacer()
                    statusIndicator
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(fileType.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(fileType.isEnabled ? .primary : .secondary)
                    
                    Text(fileType.extensions.prefix(3).joined(separator: ", "))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(fileType.isEnabled ? 
                        Color(NSColor.controlBackgroundColor).opacity(0.9) :
                        Color(NSColor.controlBackgroundColor).opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(fileType.isEnabled && isHovered ? 
                                Color(red: 1.0, green: 0.5, blue: 0.3).opacity(0.4) : 
                                Color.clear, lineWidth: 2)
                    )
            )
            .scaleEffect(isHovered ? 1.03 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}


// New helper components for enhanced preferences

// Folder toggle row for source selection
struct FolderToggleRow: View {
    let title: String
    let path: String
    let icon: String
    @Binding var isEnabled: Bool
    let accentColor: Color
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isEnabled ? 
                    LinearGradient(colors: [accentColor, accentColor.opacity(0.7)],
                                 startPoint: .topLeading,
                                 endPoint: .bottomTrailing) :
                    LinearGradient(colors: [Color.gray.opacity(0.4)],
                                 startPoint: .topLeading,
                                 endPoint: .bottomTrailing))
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isEnabled ? .primary : .secondary)
                Text(path)
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

// Smart destination row for file type mapping
struct SmartDestinationRow: View {
    let fileType: FileType
    @ObservedObject var vacManager: VacManager
    @State private var isHovered = false
    
    var accentColor: Color {
        switch fileType.name {
        case "Screenshots": return Color(red: 1.0, green: 0.5, blue: 0.3)
        case "Documents": return Color(red: 0.3, green: 0.5, blue: 1.0)
        case "Media": return Color(red: 0.2, green: 0.8, blue: 0.5)
        case "Archives": return Color(red: 0.8, green: 0.3, blue: 0.8)
        default: return Color.gray
        }
    }
    
    var destinationText: String {
        switch fileType.destination {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .typeFolder: return fileType.name
        case .custom: return fileType.customDestination?.lastPathComponent ?? "Custom"
        case .skip: return "Skip"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: fileType.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(accentColor)
                .frame(width: 20)
            
            Text(fileType.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 80, alignment: .leading)
            
            Image(systemName: "arrow.right")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text(destinationText)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Button("Change") {
                // TODO: Show destination picker
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundColor(accentColor)
            .opacity(isHovered ? 1.0 : 0.0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? 
                    Color(NSColor.controlBackgroundColor).opacity(0.5) :
                    Color.clear)
        )
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

// Day selector button
struct DayButton: View {
    let day: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Text(day)
                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : .secondary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isSelected ? 
                            LinearGradient(colors: [Color(red: 1.0, green: 0.5, blue: 0.3), 
                                                   Color(red: 1.0, green: 0.3, blue: 0.5)],
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing) :
                            LinearGradient(colors: [Color.gray.opacity(0.1)],
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing))
                )
                .scaleEffect(isHovered ? 1.1 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
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
                .foregroundStyle(RackOffColors.sunset)
            
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