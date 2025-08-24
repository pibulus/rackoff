import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vacManager: VacManager
    @State private var isVacuuming = false
    @State private var hoveredRow: UUID? = nil
    @State private var buttonHovered = false
    @State private var gearHovered = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var lastCleanResult: (files: Int, bytes: Int64) = (0, 0)
    
    var successMessage: String {
        if lastCleanResult.files == 0 {
            return "Already Clean!"
        } else if lastCleanResult.bytes > 0 {
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            let sizeString = formatter.string(fromByteCount: lastCleanResult.bytes)
            return "\(lastCleanResult.files) files • \(sizeString)"
        } else {
            return "\(lastCleanResult.files) files cleaned"
        }
    }
    
    // Cached gradients for performance
    static let titleGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.5, blue: 0.3), 
                Color(red: 1.0, green: 0.3, blue: 0.5)],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let iconGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.6, blue: 0.2), 
                Color(red: 1.0, green: 0.4, blue: 0.6)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        VStack(spacing: 20) {
            // RackOff branding with settings gear
            ZStack {
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Self.iconGradient)
                        Text("RackOff")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundStyle(Self.titleGradient)
                    }
                    Text("Desktop cleaning that gets it")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                // Settings gear in top right
                HStack {
                    Spacer()
                    Button(action: {
                        // Post notification to open preferences
                        NotificationCenter.default.post(name: Notification.Name("ShowPreferences"), object: nil)
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Self.iconGradient)
                            .opacity(gearHovered ? 1.0 : 0.6)
                            .scaleEffect(gearHovered ? 1.15 : 1.0)
                            .rotationEffect(.degrees(gearHovered ? 15 : 0))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onHover { hovering in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            gearHovered = hovering
                        }
                    }
                    .help("Preferences")
                }
                .offset(y: -20)
            }
            
            // File type toggles
            LazyVStack(spacing: 8) {
                ForEach(vacManager.fileTypes) { fileType in
                    FileTypeRow(
                        fileType: fileType,
                        vacManager: vacManager,
                        isHovered: hoveredRow == fileType.id,
                        organizationMode: vacManager.organizationMode
                    )
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            hoveredRow = hovering ? fileType.id : nil
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            
            Spacer(minLength: 4)
            
            // Organization mode picker
            HStack(spacing: 8) {
                OrganizationButton(
                    title: "Quick",
                    mode: .quickArchive,
                    vacManager: vacManager
                )
                
                OrganizationButton(
                    title: "Sort",
                    mode: .sortByType,
                    vacManager: vacManager
                )
                
                OrganizationButton(
                    title: "Smart",
                    mode: .smartClean,
                    vacManager: vacManager
                )
            }
            .padding(4)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
            .cornerRadius(10)
            
            // Progress indicator for large operations
            if vacManager.isProcessing && vacManager.currentProgress.total > 0 {
                VStack(spacing: 4) {
                    ProgressView(value: Double(vacManager.currentProgress.current), 
                                total: Double(vacManager.currentProgress.total))
                        .progressViewStyle(LinearProgressViewStyle(tint: Color(red: 1.0, green: 0.5, blue: 0.3)))
                    
                    Text("\(vacManager.currentProgress.current) of \(vacManager.currentProgress.total) files")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .transition(.opacity.combined(with: .scale))
            }
            
            // Clean Now button
            Button(action: performVacuum) {
                ZStack {
                    // Glow effect when hovering
                    if buttonHovered && !isVacuuming {
                        RoundedRectangle(cornerRadius: 25)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.4, blue: 0.4).opacity(0.3), 
                                            Color(red: 1.0, green: 0.6, blue: 0.2).opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .blur(radius: 10)
                            .frame(height: 54)
                    }
                    
                    HStack(spacing: 8) {
                        if isVacuuming {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else if showSuccess {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 16, weight: .semibold))
                                .rotationEffect(.degrees(buttonHovered ? -10 : 0))
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: buttonHovered)
                        }
                        Text(isVacuuming ? "Cleaning..." : (showSuccess ? successMessage : "Clean Now"))
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        LinearGradient(
                            colors: isVacuuming ? 
                                [Color(red: 0.6, green: 0.6, blue: 0.6), Color(red: 0.7, green: 0.7, blue: 0.7)] :
                                [Color(red: 1.0, green: 0.4, blue: 0.4), 
                                 Color(red: 1.0, green: 0.6, blue: 0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(24)
                    .shadow(color: buttonHovered ? 
                        Color(red: 1.0, green: 0.5, blue: 0.3).opacity(0.4) : 
                        Color.black.opacity(0.15), 
                        radius: buttonHovered ? 12 : 4, 
                        x: 0, 
                        y: buttonHovered ? 6 : 2)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isVacuuming)
            .scaleEffect(buttonHovered && !isVacuuming ? 1.05 : (isVacuuming ? 0.98 : 1.0))
            .accessibilityLabel(isVacuuming ? "Cleaning in progress" : "Clean desktop now")
            .onHover { hovering in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    buttonHovered = hovering
                }
            }
            
            // Error message
            if showError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                    Text(errorMessage)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 80)
        .padding(.bottom, 40)
        .frame(width: 340, height: 580)
    }
    
    func performVacuum() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isVacuuming = true
            showSuccess = false
            showError = false
        }
        
        Task {
            // Add processing delay for UX feel
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s
            
            let result = await vacManager.vacuum()
            
            // Brief delay before showing success
            try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s
            
            await MainActor.run {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isVacuuming = false
                    lastCleanResult = (result.movedCount, result.totalBytes)
                    
                    if !result.errors.isEmpty {
                        showError = true
                        errorMessage = result.errors.first ?? "Some files couldn't be moved"
                        showSuccess = false
                    } else {
                        showSuccess = true // Always show success state to display result
                        showError = false
                    }
                }
            }
            
            // Reset states after delay
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3s
            
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) {
                    showSuccess = false
                    showError = false
                }
            }
        }
    }
}

struct OrganizationButton: View {
    let title: String
    let mode: OrganizationMode
    @ObservedObject var vacManager: VacManager
    @State private var isHovered = false
    
    var isSelected: Bool { vacManager.organizationMode == mode }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                vacManager.organizationMode = mode
            }
        }) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .white : (isHovered ? .primary : .secondary))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if isSelected {
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.5, blue: 0.3), 
                                        Color(red: 1.0, green: 0.3, blue: 0.5)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else if isHovered {
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.5, blue: 0.3).opacity(0.15), 
                                        Color(red: 1.0, green: 0.3, blue: 0.5).opacity(0.1)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else {
                            Color.clear
                        }
                    }
                )
                .cornerRadius(6)
                .scaleEffect(isHovered && !isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct FileTypeRow: View {
    let fileType: FileType
    @ObservedObject var vacManager: VacManager
    let isHovered: Bool
    let organizationMode: OrganizationMode
    
    // Color per file type
    var accentColor: Color {
        switch fileType.name {
        case "Screenshots": return Color(red: 1.0, green: 0.5, blue: 0.3)
        case "Documents": return Color(red: 0.4, green: 0.6, blue: 0.9)
        case "Media": return Color(red: 0.3, green: 0.8, blue: 0.5)
        case "Archives": return Color(red: 0.8, green: 0.4, blue: 0.8)
        default: return Color.accentColor
        }
    }
    
    // Destination text based on organization mode
    var destinationText: String? {
        switch organizationMode {
        case .quickArchive:
            return "→ Daily"
        case .sortByType:
            return "→ \(fileType.name)/"
        case .smartClean:
            switch fileType.destination {
            case .daily:
                return "→ Daily"
            case .weekly:
                return "→ Weekly"
            case .monthly:
                return "→ Monthly"
            case .typeFolder:
                return "→ \(fileType.name)/"
            case .custom:
                if let customDest = fileType.customDestination {
                    return "→ \(customDest.lastPathComponent)"
                } else {
                    return "→ Custom"
                }
            case .skip:
                return "→ Skip"
            }
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: fileType.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(fileType.isEnabled ? accentColor : .secondary)
                .frame(width: 24)
                .scaleEffect(isHovered ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(fileType.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(fileType.isEnabled ? .primary : .secondary)
                
                if let destinationText = destinationText, fileType.isEnabled {
                    Text(destinationText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(accentColor.opacity(0.8))
                }
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { fileType.isEnabled },
                set: { vacManager.toggleFileType(fileType, enabled: $0) }
            ))
            .toggleStyle(SwitchToggleStyle(tint: accentColor))
            .labelsHidden()
            .accessibilityLabel("Enable \(fileType.name) cleaning")
            .scaleEffect(0.85)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? 
                    Color(NSColor.controlBackgroundColor) : 
                    Color.clear
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                vacManager.toggleFileType(fileType, enabled: !fileType.isEnabled)
            }
        }
        .contextMenu {
            if organizationMode == .smartClean {
                Section("Send \(fileType.name) to:") {
                    Button("Daily folders") {
                        vacManager.updateFileTypeDestination(fileType, destination: .daily)
                    }
                    Button("Weekly folders") {
                        vacManager.updateFileTypeDestination(fileType, destination: .weekly)
                    }
                    Button("Monthly folders") {
                        vacManager.updateFileTypeDestination(fileType, destination: .monthly)
                    }
                    Button("\(fileType.name) folder") {
                        vacManager.updateFileTypeDestination(fileType, destination: .typeFolder)
                    }
                    Button("Custom folder...") {
                        vacManager.updateFileTypeDestination(fileType, destination: .custom)
                        // Note: User needs to set custom destination in Preferences
                    }
                }
                
                Section {
                    Button("Skip this type") {
                        vacManager.updateFileTypeDestination(fileType, destination: .skip)
                    }
                }
            }
        }
    }
}