import SwiftUI

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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let statusButton = statusItem.button {
            statusButton.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "RackOff")
            statusButton.action = #selector(handleClick)
            statusButton.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Setup popover
        let contentView = ContentView()
        popover.contentSize = NSSize(width: 340, height: 610)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)
    }
    
    @objc func handleClick() {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            // Show context menu on right-click
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "About RackOff", action: #selector(showAbout), keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
            
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            // Toggle popover on left-click
            togglePopover()
        }
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
        NSApp.orderFrontStandardAboutPanel(nil)
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}