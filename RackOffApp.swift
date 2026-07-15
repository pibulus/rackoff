import SwiftUI
import ServiceManagement

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
    case broom = "broom"
    case sparkles = "sparkles"
    case wandStars = "wand.and.stars"
    case wind = "wind"
    case rays = "rays"
    case dottedCircle = "circle.dotted"
    
    var symbolName: String { rawValue }
    
    var displayName: String {
        switch self {
        case .broom: return "🧹 Broom"
        case .sparkles: return "✨ Sparkles"
        case .wandStars: return "🪄 Wand & Stars"
        case .wind: return "💨 Wind"
        case .rays: return "☀️ Rays"
        case .dottedCircle: return "○ Circle"
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
    lazy var vacManager: VacManager = {
        return VacManager()
    }()
    var currentIconStyle: MenuIconStyle = .broom
    var contextMenu: NSMenu!
    var undoMenuItem: NSMenuItem!
    var launchAtLoginItem: NSMenuItem!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Load icon style preference
        if let savedStyle = UserDefaults.standard.string(forKey: "menuIconStyle"),
           let style = MenuIconStyle(rawValue: savedStyle) {
            currentIconStyle = style
        }
        
        // Listen for preferences notification
        NotificationCenter.default.addObserver(self, selector: #selector(showPreferences), name: Notification.Name("ShowPreferences"), object: nil)
        
        // Create menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let statusButton = statusItem.button {
            statusButton.image = createIconImage()
            statusButton.action = #selector(handleClick)
            statusButton.sendAction(on: [.leftMouseUp, .rightMouseUp])
            statusButton.target = self
        }
        
        // Setup popovers
        setupPopovers()
        
        // Setup context menu once
        setupContextMenu()
    }
    
    private func setupPopovers() {
        // Setup main popover
        let contentView = ContentView().environmentObject(vacManager)
        popover.contentSize = NSSize(width: 340, height: 500)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)
        
        // Setup about popover
        let aboutView = AboutView()
        aboutPopover.contentSize = NSSize(width: 300, height: 220)
        aboutPopover.behavior = .transient
        aboutPopover.contentViewController = NSHostingController(rootView: aboutView)
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
        
        launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.target = self
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        contextMenu.addItem(launchAtLoginItem)
        
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
        
        // Update launch at login checkmark
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }
    
    private func flashIcon() {
        statusItem.button?.alphaValue = 0.4
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.statusItem.button?.alphaValue = 1.0
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
            NSLog("Undo completed: \(result.restoredCount) files restored")
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
    
    @objc func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
                launchAtLoginItem.state = .off
            } else {
                try SMAppService.mainApp.register()
                launchAtLoginItem.state = .on
            }
        } catch {
            NSLog("Launch at Login toggle failed: \(error)")
        }
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    private func createIconImage() -> NSImage {
        guard let image = NSImage(systemSymbolName: currentIconStyle.symbolName, accessibilityDescription: "RackOff") else {
            return NSImage(size: NSSize(width: 18, height: 18))
        }
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let configured = image.withSymbolConfiguration(config) ?? image
        configured.isTemplate = true
        return configured
    }
}