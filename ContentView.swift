import SwiftUI

struct ContentView: View {
    @StateObject private var vacManager = VacManager()
    @State private var isVacuuming = false
    @State private var hoveredRow: UUID? = nil
    @State private var buttonHovered = false
    
    var body: some View {
        VStack(spacing: 24) {
            // RackOff branding - bring it back!
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.6, blue: 0.2), 
                                        Color(red: 1.0, green: 0.4, blue: 0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text("RackOff")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.5, blue: 0.3), 
                                        Color(red: 1.0, green: 0.3, blue: 0.5)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                Text("Your desktop's best friend")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 12)
            
            // File types with more color
            VStack(spacing: 8) {
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
            .padding(.vertical, 8)
            
            Spacer(minLength: 20)
            
            // Schedule toggle - cleaner
            Picker("", selection: $vacManager.schedule) {
                Text("Manual").tag(Schedule.manual)
                Text("Daily").tag(Schedule.daily)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            
            // THE LUSH CLEAN NOW BUTTON
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
                        } else {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 16, weight: .semibold))
                                .rotationEffect(.degrees(buttonHovered ? -10 : 0))
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: buttonHovered)
                        }
                        Text(isVacuuming ? "Cleaning..." : "Clean Now")
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
            .onHover { hovering in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    buttonHovered = hovering
                }
            }
        }
        .padding(24)
        .frame(width: 340, height: 500)
    }
    
    func performVacuum() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isVacuuming = true
        }
        
        Task {
            await vacManager.vacuum()
            
            await MainActor.run {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isVacuuming = false
                }
            }
        }
    }
}

struct FileTypeRow: View {
    let fileType: FileType
    @ObservedObject var vacManager: VacManager
    let isHovered: Bool
    
    // Color per file type
    var accentColor: Color {
        switch fileType.name {
        case "Screenshots": return Color(red: 1.0, green: 0.5, blue: 0.3)
        case "PDFs": return Color(red: 0.4, green: 0.6, blue: 0.9)
        case "Images": return Color(red: 0.3, green: 0.8, blue: 0.5)
        case "Downloads": return Color(red: 0.8, green: 0.4, blue: 0.8)
        case "Documents": return Color(red: 0.6, green: 0.5, blue: 0.9)
        default: return Color.accentColor
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
            
            VStack(alignment: .leading, spacing: 1) {
                Text(fileType.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(fileType.isEnabled ? .primary : .secondary)
                if fileType.isEnabled {
                    Text(fileType.extensions.prefix(3).joined(separator: ", "))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .opacity(0.7)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { fileType.isEnabled },
                set: { vacManager.toggleFileType(fileType, enabled: $0) }
            ))
            .toggleStyle(SwitchToggleStyle(tint: accentColor))
            .labelsHidden()
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
    }
}