import SwiftUI

// MARK: - RackOff Design System
struct RackOffColors {
    // Primary brand gradient
    static let sunset = LinearGradient(
        colors: [Color(red: 1.0, green: 0.5, blue: 0.3), 
                Color(red: 1.0, green: 0.3, blue: 0.5)],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // Subtle background variations
    static let subtleBackground = LinearGradient(
        colors: [Color(red: 1.0, green: 0.5, blue: 0.3).opacity(0.05), 
                Color(red: 1.0, green: 0.3, blue: 0.5).opacity(0.03)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let hoverBackground = LinearGradient(
        colors: [Color(red: 1.0, green: 0.5, blue: 0.3).opacity(0.15), 
                Color(red: 1.0, green: 0.3, blue: 0.5).opacity(0.1)],
        startPoint: .leading,
        endPoint: .trailing
    )
}

struct RackOffSpacing {
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let extraLarge: CGFloat = 32
    
    // Specific UI spacings
    static let popoverPadding: CGFloat = 24
    static let buttonSpacing: CGFloat = 8
    static let sectionSpacing: CGFloat = 20
}

struct RackOffSizes {
    // Main popover
    static let popoverWidth: CGFloat = 340
    static let popoverHeight: CGFloat = 580
    
    // Preferences window
    static let preferencesWidth: CGFloat = 600
    static let preferencesHeight: CGFloat = 500
    
    // Corner radius
    static let buttonRadius: CGFloat = 6
    static let cardRadius: CGFloat = 8
    static let containerRadius: CGFloat = 10
}

// MARK: - Animation Constants
struct RackOffAnimations {
    static let quickSpring = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let smoothSpring = Animation.spring(response: 0.3, dampingFraction: 0.6)
    static let fastEase = Animation.easeInOut(duration: 0.15)
}