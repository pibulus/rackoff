import SwiftUI

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

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover = NSPopover()
    var currentIconStyle: MenuIconStyle = .sparkles
    var isPressed: Bool = false
    
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
        
        // Setup popover
        let contentView = ContentView()
        popover.contentSize = NSSize(width: 340, height: 610)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)
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
    
    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "About RackOff", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
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
        menu.addItem(styleMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        
        // Show menu at button location
        if let button = statusItem.button {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
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
        let alert = NSAlert()
        alert.messageText = "✨ RackOff"
        alert.informativeText = """
        A minimal macOS menu bar app that racks off desktop clutter into organized daily archives.
        
        Part of the SoftStack suite - $1 apps that do one thing perfectly.
        
        Version 1.0
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Nice!")
        alert.runModal()
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    private func createIconImage() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // Clear background
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        if let context = NSGraphicsContext.current?.cgContext {
            switch currentIconStyle {
            case .sparkles:
                drawSparkles(context: context, size: size)
            case .circle:
                drawCircle(context: context, size: size)
            case .dot:
                drawDot(context: context, size: size)
            }
        }
        
        image.unlockFocus()
        image.isTemplate = false
        
        return image
    }
    
    private func drawSparkles(context: CGContext, size: NSSize) {
        // Main star (center) - orange
        drawCGStar(context: context, 
                  center: CGPoint(x: size.width * 0.5, y: size.height * 0.5),
                  size: size.width * 0.4,
                  color: darkenIfPressed(NSColor.systemOrange).cgColor)
        
        // Small stars - pink and yellow
        drawCGStar(context: context,
                  center: CGPoint(x: size.width * 0.2, y: size.height * 0.7),
                  size: size.width * 0.15,
                  color: darkenIfPressed(NSColor.systemPink).cgColor)
        
        drawCGStar(context: context,
                  center: CGPoint(x: size.width * 0.8, y: size.height * 0.2),
                  size: size.width * 0.12,
                  color: darkenIfPressed(NSColor.systemYellow).cgColor)
        
        drawCGStar(context: context,
                  center: CGPoint(x: size.width * 0.75, y: size.height * 0.75),
                  size: size.width * 0.13,
                  color: darkenIfPressed(NSColor.systemPink).cgColor)
    }
    
    private func drawCircle(context: CGContext, size: NSSize) {
        let color = darkenIfPressed(NSColor.systemBlue)
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