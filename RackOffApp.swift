import SwiftUI
import UniformTypeIdentifiers

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
        }
        .padding()
        .frame(width: 600, height: 500)
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

struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            // RackOff branding
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.6, blue: 0.2), 
                                    Color(red: 1.0, green: 0.4, blue: 0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("RackOff")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.5, blue: 0.3), 
                                    Color(red: 1.0, green: 0.3, blue: 0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .padding(.bottom, 4)
            
            Text("Desktop chaos? Not anymore.")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .italic()
            
            Text("One click. Clean desktop. Back to whatever you were doing.")
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("Made by Pablo in Bangkok")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.8))
                
                Text("Version 1.0")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.6))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 32)
        .frame(width: 300, height: 220)
    }
}

enum MenuIconStyle: String, CaseIterable {
    case sparkles = "sparkles"
    case circle = "circle" 
    case dot = "dot"
    
    var displayName: String {
        switch self {
        case .sparkles: return "✨ Sparkles"
        case .circle: return "○ Circle"
        case .dot: return "● Dot"
        }
    }
}

@main
struct RackOffApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover = NSPopover()
    var aboutPopover = NSPopover()
    var preferencesWindow: NSWindow?
    var vacManager = VacManager()
    var currentIconStyle: MenuIconStyle = .sparkles
    var isPressed: Bool = false
    var contextMenu: NSMenu!
    var undoMenuItem: NSMenuItem!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Load icon style preference
        if let savedStyle = UserDefaults.standard.string(forKey: "menuIconStyle"),
           let style = MenuIconStyle(rawValue: savedStyle) {
            currentIconStyle = style
        }
        
        // Create menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let statusButton = statusItem.button {
            statusButton.image = createIconImage()
            statusButton.action = #selector(handleClick)
            statusButton.sendAction(on: [.leftMouseUp, .rightMouseUp])
            statusButton.target = self
        }
        
        // Setup main popover
        let contentView = ContentView().environmentObject(vacManager)
        popover.contentSize = NSSize(width: 340, height: 630)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)
        
        // Setup about popover
        let aboutView = AboutView()
        aboutPopover.contentSize = NSSize(width: 300, height: 220)
        aboutPopover.behavior = .transient
        aboutPopover.contentViewController = NSHostingController(rootView: aboutView)
        
        // Setup context menu once
        setupContextMenu()
    }
    
    @objc func handleClick() {
        guard let event = NSApp.currentEvent else { return }
        
        // Add visual feedback
        flashIcon()
        
        if event.type == .rightMouseUp {
            // Show context menu on right-click
            showContextMenu()
        } else {
            // Toggle popover on left-click
            togglePopover()
        }
    }
    
    private func setupContextMenu() {
        contextMenu = NSMenu()
        
        // Undo item (shown when available)
        undoMenuItem = NSMenuItem(title: "Undo Last Clean", action: #selector(undoLastClean), keyEquivalent: "z")
        undoMenuItem.target = self
        undoMenuItem.isHidden = !vacManager.canUndo
        contextMenu.addItem(undoMenuItem)
        
        contextMenu.addItem(NSMenuItem.separator())
        contextMenu.addItem(NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ","))
        contextMenu.addItem(NSMenuItem.separator())
        contextMenu.addItem(NSMenuItem(title: "About RackOff", action: #selector(showAbout), keyEquivalent: ""))
        contextMenu.addItem(NSMenuItem.separator())
        
        // Add icon style submenu
        let styleMenu = NSMenu()
        for style in MenuIconStyle.allCases {
            let item = NSMenuItem(title: style.displayName, action: #selector(changeIconStyle(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = style
            item.state = (style == currentIconStyle) ? .on : .off
            styleMenu.addItem(item)
        }
        
        let styleMenuItem = NSMenuItem(title: "Icon Style", action: nil, keyEquivalent: "")
        styleMenuItem.submenu = styleMenu
        contextMenu.addItem(styleMenuItem)
        
        contextMenu.addItem(NSMenuItem.separator())
        contextMenu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
    }
    
    private func showContextMenu() {
        // Update checkmarks before showing
        updateMenuCheckmarks()
        
        // Show menu at button location
        if let button = statusItem.button {
            contextMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
        }
    }
    
    private func updateMenuCheckmarks() {
        // Update undo visibility
        undoMenuItem.isHidden = !vacManager.canUndo
        
        // Update icon style checkmarks
        if let styleMenuItem = contextMenu.item(withTitle: "Icon Style"),
           let styleSubmenu = styleMenuItem.submenu {
            for item in styleSubmenu.items {
                if let itemStyle = item.representedObject as? MenuIconStyle {
                    item.state = (itemStyle == currentIconStyle) ? .on : .off
                }
            }
        }
    }
    
    private func flashIcon() {
        isPressed = true
        statusItem.button?.image = createIconImage()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isPressed = false
            self.statusItem.button?.image = self.createIconImage()
        }
    }
    
    @objc func changeIconStyle(_ sender: NSMenuItem) {
        guard let style = sender.representedObject as? MenuIconStyle else { return }
        currentIconStyle = style
        UserDefaults.standard.set(style.rawValue, forKey: "menuIconStyle")
        statusItem.button?.image = createIconImage()
        // Menu checkmarks are updated automatically when shown next time
    }
    
    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
    
    @objc func showAbout() {
        if let button = statusItem.button {
            if aboutPopover.isShown {
                aboutPopover.performClose(nil)
            } else {
                popover.performClose(nil) // Close main popover if open
                aboutPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
    
    @objc func undoLastClean() {
        Task {
            let result = await vacManager.undoLastClean()
            print("Undo completed: \(result.restoredCount) files restored")
        }
    }
    
    @objc func showPreferences() {
        if preferencesWindow == nil {
            // Create preferences window
            let preferencesView = PreferencesView().environmentObject(vacManager)
            let hostingController = NSHostingController(rootView: preferencesView)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "RackOff Preferences"
            window.contentViewController = hostingController
            window.isReleasedWhenClosed = false
            preferencesWindow = window
        }
        
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    private func createIconImage() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        
        return NSImage(size: size, flipped: false) { rect in
            // Clear background
            NSColor.clear.setFill()
            rect.fill()
            
            if let context = NSGraphicsContext.current?.cgContext {
                switch self.currentIconStyle {
                case .sparkles:
                    self.drawSparkles(context: context, size: size)
                case .circle:
                    self.drawCircle(context: context, size: size)
                case .dot:
                    self.drawDot(context: context, size: size)
                }
            }
            
            return true
        }
    }
    
    private func drawSparkles(context: CGContext, size: NSSize) {
        let color = darkenIfPressed(NSColor.controlAccentColor)
        
        // Main star (center)
        drawCGStar(context: context, 
                  center: CGPoint(x: size.width * 0.5, y: size.height * 0.5),
                  size: size.width * 0.4,
                  color: color.cgColor)
        
        // Small stars around it
        drawCGStar(context: context,
                  center: CGPoint(x: size.width * 0.2, y: size.height * 0.7),
                  size: size.width * 0.15,
                  color: color.cgColor)
        
        drawCGStar(context: context,
                  center: CGPoint(x: size.width * 0.8, y: size.height * 0.2),
                  size: size.width * 0.12,
                  color: color.cgColor)
        
        drawCGStar(context: context,
                  center: CGPoint(x: size.width * 0.75, y: size.height * 0.75),
                  size: size.width * 0.13,
                  color: color.cgColor)
    }
    
    private func drawCircle(context: CGContext, size: NSSize) {
        let color = darkenIfPressed(NSColor.controlAccentColor)
        context.setFillColor(color.cgColor)
        
        let radius = size.width * 0.3
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        
        context.fillEllipse(in: rect)
    }
    
    private func drawDot(context: CGContext, size: NSSize) {
        let color = darkenIfPressed(NSColor.controlAccentColor)
        context.setFillColor(color.cgColor)
        
        let radius = size.width * 0.2
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        
        context.fillEllipse(in: rect)
    }
    
    private func darkenIfPressed(_ color: NSColor) -> NSColor {
        return isPressed ? color.withSystemEffect(.pressed) : color
    }
    
    private func drawCGStar(context: CGContext, center: CGPoint, size: CGFloat, color: CGColor) {
        context.setFillColor(color)
        
        let radius = size / 2
        let innerRadius = radius * 0.4
        let points = 4
        
        let path = CGMutablePath()
        
        for i in 0..<points * 2 {
            let angle = CGFloat(i) * .pi / CGFloat(points)
            let currentRadius = i % 2 == 0 ? radius : innerRadius
            let x = center.x + cos(angle) * currentRadius
            let y = center.y + sin(angle) * currentRadius
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        
        context.addPath(path)
        context.fillPath()
    }
}