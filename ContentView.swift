import SwiftUI

// MARK: - Main Popover View
/// The primary interface for RackOff - shows file types, organization modes, and clean button
struct ContentView: View {
    @EnvironmentObject var vacManager: VacManager
    @State private var isVacuuming = false
    @State private var hoveredRow: UUID? = nil
    @State private var buttonHovered = false
    @State private var gearHovered = false
    @State private var gearScale: CGFloat = 1.0
    @State private var exitHovered = false
    @State private var exitScale: CGFloat = 1.0
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var lastCleanResult: (files: Int, bytes: Int64) = (0, 0)
    @State private var successPop: CGFloat = 1.0   // juicy bounce on a finished clean
    @State private var stashHovered = false
    
    // Feeling first, number second. The payoff is the empty desktop, not the stat —
    // the count rides along quietly so it still feels concrete.
    var successMessage: String {
        if lastCleanResult.files == 0 {
            return "Already spotless ✨"
        } else {
            let n = lastCleanResult.files
            return "All clear ✨ · \(n) file\(n == 1 ? "" : "s")"
        }
    }
    
    // Use consistent brand colors
    
    var body: some View {
        VStack(spacing: 12) {
            // Header with settings and exit buttons
            HStack {
                Button(action: {
                    // Tactile click animation
                    withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) {
                        gearScale = 1.3
                    }
                    
                    // Post notification
                    NotificationCenter.default.post(name: Notification.Name("ShowPreferences"), object: nil)
                    
                    // Reset scale
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            gearScale = 1.0
                        }
                    }
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(gearHovered ? Color(red: 1.0, green: 0.5, blue: 0.3) : Color.secondary)
                        .scaleEffect(gearScale * (gearHovered ? 1.1 : 1.0))
                        .rotationEffect(.degrees(gearHovered ? 15 : 0))
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { hovering in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        gearHovered = hovering
                    }
                }
                .help("Preferences")
                
                Spacer()
                
                // RackOff branding - centered
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(RackOffColors.sunset)
                    Text("RackOff")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(RackOffColors.sunset)
                }
                
                Spacer()
                
                Button(action: {
                    // Tactile click animation
                    withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) {
                        exitScale = 0.7
                    }
                    
                    // Brief delay then quit
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        NSApplication.shared.terminate(nil)
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(exitHovered ? Color.red.opacity(0.8) : Color.secondary)
                        .opacity(exitHovered ? 1.0 : 0.7)
                        .scaleEffect(exitScale * (exitHovered ? 1.15 : 1.0))
                        .rotationEffect(.degrees(exitHovered ? 90 : 0))
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { hovering in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        exitHovered = hovering
                        if !hovering {
                            exitScale = 1.0
                        }
                    }
                }
                .help("Quit RackOff")
            }
            .padding(.horizontal, 4)
            
            // File type toggles with more space
            LazyVStack(spacing: 8) {
                ForEach(vacManager.fileTypes) { fileType in
                    FileTypeRow(
                        fileType: fileType,
                        vacManager: vacManager,
                        isHovered: hoveredRow == fileType.id
                    )
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            hoveredRow = hovering ? fileType.id : nil
                        }
                    }
                }
            }
            .padding(.vertical, 2)

            // Peek: the carpet bag or success banner
            if showSuccess && lastCleanResult.files > 0 {
                SuccessBannerView(
                    filesCount: lastCleanResult.files,
                    onOpenStash: {
                        openStash()
                        withAnimation(.easeOut(duration: 0.2)) {
                            showSuccess = false
                        }
                    },
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showSuccess = false
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("Recently racked")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: openStash) {
                            HStack(spacing: 3) {
                                Text("Open Stash")
                                Image(systemName: "arrow.up.forward.app")
                            }
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(RackOffColors.sunset)
                            .opacity(stashHovered ? 1.0 : 0.7)
                            .scaleEffect(stashHovered ? 1.05 : 1.0)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onHover { hovering in
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                                stashHovered = hovering
                            }
                            if hovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                    
                    if vacManager.recentlyRacked.isEmpty {
                        PeekEmptyState()
                            .transition(.opacity)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(vacManager.recentlyRacked) { item in
                                    PeekChip(item: item)
                                }
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(NSColor.controlBackgroundColor).opacity(0.35))
                        )
                    }
                }
            }

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
                                .scaleEffect(successPop)
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 16, weight: .semibold))
                                .rotationEffect(.degrees(buttonHovered ? -10 : 0))
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: buttonHovered)
                        }
                        Text(isVacuuming ? "Cleaning..." : (showSuccess && lastCleanResult.files == 0 ? successMessage : "Clean Now"))
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
            .scaleEffect((buttonHovered && !isVacuuming ? 1.05 : (isVacuuming ? 0.98 : 1.0)) * successPop)
            .accessibilityLabel(isVacuuming ? "Cleaning in progress" : "Clean desktop now")
            .onHover { hovering in
                withAnimation(RackOffAnimations.quickSpring) {
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
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .frame(width: RackOffSizes.popoverWidth, height: RackOffSizes.popoverHeight)
    }
    
    func openStash() {
        NSWorkspace.shared.open(vacManager.destinationFolder)
    }

    func performVacuum() {
        withAnimation(RackOffAnimations.quickSpring) {
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
                withAnimation(RackOffAnimations.quickSpring) {
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

            // Juicy pop: a quick bounce on the button + sparkle the moment it lands.
            // Calm-but-alive — one satisfying beat, not confetti.
            if result.errors.isEmpty {
                await MainActor.run {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
                        successPop = 1.12
                    }
                }
                try? await Task.sleep(nanoseconds: 180_000_000)
                await MainActor.run {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                        successPop = 1.0
                    }
                }
            }

            // Reset states after delay (longer for completion banner so they can click it)
            let delayNanoseconds: UInt64 = result.movedCount > 0 ? 8_000_000_000 : 2_800_000_000
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) {
                    showSuccess = false
                    showError = false
                }
            }
        }
    }
}

// MARK: - File Type Toggle Row
/// Individual file type with toggle, icon, and destination info
struct FileTypeRow: View {
    let fileType: FileType
    @ObservedObject var vacManager: VacManager
    let isHovered: Bool
    @State private var toggleScale: CGFloat = 1.0

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

    var body: some View {
        HStack(spacing: 0) {
            // Main content area
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

                    if fileType.isEnabled {
                        Text("→ \(destinationLabel(for: fileType))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(accentColor.opacity(0.8))
                    }
                }

                Spacer()
            }
            .contentShape(Rectangle())

            // Toggle area - separate hit target with satisfying animation
            Toggle("", isOn: Binding(
                get: { fileType.isEnabled },
                set: { newValue in
                    // Trigger satisfying animation
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                        toggleScale = 1.3
                    }
                    vacManager.toggleFileType(fileType, enabled: newValue)
                    
                    // Reset scale
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            toggleScale = 1.0
                        }
                    }
                }
            ))
            .toggleStyle(SwitchToggleStyle(tint: accentColor))
            .labelsHidden()
            .accessibilityLabel("Enable \(fileType.name) cleaning")
            .scaleEffect(toggleScale * 0.85)
            .padding(.trailing, 8)
        }
        .padding(.vertical, 8)
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ?
                    Color(NSColor.controlBackgroundColor).opacity(0.8) :
                    Color.clear
                )
        )
        .contentShape(Rectangle())
    }

    private func destinationLabel(for fileType: FileType) -> String {
        switch vacManager.organizationMode {
        case .quickArchive:
            return "Nested by Date"
        case .sortByType:
            return "Category Folder (\(fileType.name))"
        case .smartClean:
            switch fileType.destination {
            case .daily: return "Daily folders"
            case .weekly: return "Weekly folders"
            case .monthly: return "Monthly folders"
            case .typeFolder: return "Category folder"
            case .custom: return "Custom folder"
            case .skip: return "Skip"
            }
        }
    }
}

// MARK: - Peek Empty State
/// Shown before the first-ever clean. The whole job is one sentence of reassurance:
/// your stuff gets put away, not thrown away, and it'll be right here. Answers the
/// "where did everything go?" fear before the user has even clicked Clean.
struct PeekEmptyState: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "archivebox")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary.opacity(0.6))

            VStack(alignment: .leading, spacing: 2) {
                Text("Nothing racked yet")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("Cleaned files land here — one click from Finder.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.7))
            }

            Spacer()
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                        )
                        .foregroundColor(.secondary.opacity(0.15))
                )
        )
    }
}

// MARK: - Peek Chip
/// One tidied file. Icon + name + when, in its file-type colour. Clicking reveals it
/// in Finder so "where did my stuff go" is always answered.
struct PeekChip: View {
    let item: RackedItem
    @State private var isHovered = false

    var accentColor: Color {
        switch item.accentName {
        case "Screenshots": return Color(red: 1.0, green: 0.5, blue: 0.3)
        case "Documents": return Color(red: 0.4, green: 0.6, blue: 0.9)
        case "Media": return Color(red: 0.3, green: 0.8, blue: 0.5)
        case "Archives": return Color(red: 0.8, green: 0.4, blue: 0.8)
        default: return Color.accentColor
        }
    }

    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: item.date, relativeTo: Date())
    }

    var body: some View {
        Button(action: revealInFinder) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing))
                        .frame(width: 36, height: 36)

                    Image(systemName: item.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .scaleEffect(isHovered ? 1.1 : 1.0)
                }

                Text(item.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(relativeDate)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .frame(width: 64)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ?
                        Color(NSColor.controlBackgroundColor).opacity(0.9) :
                        Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isHovered ? accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
            .scaleEffect(isHovered ? 1.04 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .help(item.name)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([item.destination])
    }
}

// MARK: - Success Banner View
/// A premium card that slides/fades in when a clean completes, prompting the user
/// to open their stash in Finder.
struct SuccessBannerView: View {
    let filesCount: Int
    let onOpenStash: () -> Void
    let onDismiss: () -> Void
    @State private var openHovered = false
    @State private var dismissHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(RackOffColors.sunset.opacity(0.15))
                    .frame(width: 38, height: 38)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(RackOffColors.sunset)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Swept \(filesCount) file\(filesCount == 1 ? "" : "s")!")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                Text("Organized safe and sound.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onOpenStash) {
                Text("Show in Finder")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: openHovered ? 
                                [Color(red: 1.0, green: 0.5, blue: 0.5), Color(red: 1.0, green: 0.7, blue: 0.3)] :
                                [Color(red: 1.0, green: 0.4, blue: 0.4), Color(red: 1.0, green: 0.6, blue: 0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(8)
                    .shadow(color: openHovered ? Color(red: 1.0, green: 0.5, blue: 0.3).opacity(0.3) : Color.clear, radius: 4, y: 2)
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(openHovered ? 1.03 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: openHovered)
            .onHover { hovering in
                openHovered = hovering
            }
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(6)
                    .background(dismissHovered ? Color.secondary.opacity(0.1) : Color.clear)
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { hovering in
                dismissHovered = hovering
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(RackOffColors.sunset.opacity(0.2), lineWidth: 1)
                )
        )
        .frame(height: 100)
    }
}