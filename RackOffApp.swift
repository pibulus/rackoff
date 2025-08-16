import SwiftUI

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
            
            Text("Your desktop's chaos nemesis")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .italic()
            
            Text("Because life's too short for messy desktops.")
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

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover = NSPopover()
    var aboutPopover = NSPopover()
    var currentIconStyle: MenuIconStyle = .sparkles
    var isPressed: Bool = false
    var contextMenu: NSMenu!
    
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
        let contentView = ContentView()
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