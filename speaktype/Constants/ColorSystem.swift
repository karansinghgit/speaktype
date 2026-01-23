import SwiftUI

// MARK: - SpeakType Design System
// Inspired by Wispr Flow - warm, seamless, typographically rich

extension Color {
    
    // MARK: - Core Palette
    
    /// Warm cream background (like Flow)
    static let cream = Color(hex: "FAF9F7")
    static let creamWarm = Color(hex: "F8F6F3")
    
    /// Dark theme
    static let ink = Color(hex: "1A1A1A")
    static let inkLight = Color(hex: "252525")
    static let inkSurface = Color(hex: "2F2F2F")
    
    /// Accent - lavender tint for selected states (like Flow)
    static let lavender = Color(hex: "F0EBFF")
    static let lavenderDark = Color(hex: "3D3560")
    
    // MARK: - Semantic Colors
    
    static let bgApp = Color(nsColor: NSColor(name: "bgApp", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua 
            ? NSColor(hex: "1A1A1A")
            : NSColor(hex: "FAF9F7")
    }))
    
    static let bgSidebar = Color(nsColor: NSColor(name: "bgSidebar", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua 
            ? NSColor(hex: "1A1A1A")
            : NSColor(hex: "FAF9F7")  // Same as bgApp - seamless
    }))
    
    static let bgSurface = Color(nsColor: NSColor(name: "bgSurface", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua 
            ? NSColor(hex: "252525")
            : NSColor(hex: "FFFFFF")
    }))
    
    static let bgCard = Color(nsColor: NSColor(name: "bgCard", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua 
            ? NSColor(hex: "252525")
            : NSColor(hex: "FFFFFF")
    }))
    
    static let bgHover = Color(nsColor: NSColor(name: "bgHover", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua 
            ? NSColor(hex: "2F2F2F")
            : NSColor(hex: "F5F4F2")
    }))
    
    static let bgSelected = Color(nsColor: NSColor(name: "bgSelected", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua 
            ? NSColor(hex: "3D3560")  // Dark lavender
            : NSColor(hex: "F0EBFF")  // Light lavender
    }))
    
    // MARK: - Borders
    
    static let border = Color(nsColor: NSColor(name: "border", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua 
            ? NSColor(hex: "3A3A3A")
            : NSColor(hex: "E8E6E3")
    }))
    
    static let borderSubtle = Color(nsColor: NSColor(name: "borderSubtle", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua 
            ? NSColor(hex: "2F2F2F")
            : NSColor(hex: "EFEDEA")
    }))
    
    static let borderCard = Color(nsColor: NSColor(name: "borderCard", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua 
            ? NSColor(hex: "3A3A3A")
            : NSColor(hex: "E8E6E3")
    }))
    
    static let borderActive = Color(hex: "2C2C54")
    
    // MARK: - Text
    
    static let textPrimary = Color(nsColor: NSColor(name: "textPrimary", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua 
            ? NSColor(hex: "FFFFFF")
            : NSColor(hex: "1A1A1A")
    }))
    
    static let textSecondary = Color(nsColor: NSColor(name: "textSecondary", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua 
            ? NSColor(hex: "A0A0A0")
            : NSColor(hex: "6B6B6B")
    }))
    
    static let textMuted = Color(nsColor: NSColor(name: "textMuted", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua 
            ? NSColor(hex: "707070")
            : NSColor(hex: "9A9A9A")
    }))
    
    static let textDisabled = Color(nsColor: NSColor(name: "textDisabled", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua 
            ? NSColor(hex: "505050")
            : NSColor(hex: "C0C0C0")
    }))
    
    // MARK: - Sidebar
    
    static let sidebarItem = Color(nsColor: NSColor(name: "sidebarItem", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua 
            ? NSColor(hex: "A0A0A0")
            : NSColor(hex: "6B6B6B")
    }))
    
    static let sidebarItemHoverBg = Color(nsColor: NSColor(name: "sidebarItemHoverBg", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua 
            ? NSColor(hex: "2F2F2F")
            : NSColor(hex: "F0EFED")
    }))
    
    // MARK: - Accents
    
    static let accentPrimary = Color(hex: "1A1A1A")  // Dark for buttons like Flow
    static let accentSuccess = Color(hex: "22C55E")
    static let accentWarning = Color(hex: "F59E0B")
    static let accentError = Color(hex: "EF4444")
    static let accentBlue = Color(hex: "3B82F6")
    
    // Legacy
    static let navyInk = Color(hex: "2C2C54")
    static let navyLight = Color(hex: "3D3D6B")
    static let navyMuted = Color(hex: "6B6B6B")
    static let charcoal = Color(hex: "1A1A1A")
    static let charcoalLight = Color(hex: "252525")
    static let charcoalSurface = Color(hex: "2F2F2F")
    static let accentWarm = Color(hex: "F59E0B")
    static let accentCool = Color(hex: "3B82F6")
    static let accentRed = Color(hex: "EF4444")
    static let accentRedSoft = Color(hex: "EF4444").opacity(0.1)
    static let accentBlueSoft = Color(hex: "3B82F6").opacity(0.1)
    
    // MARK: - Buttons
    
    static let btnPrimaryBg = Color(hex: "1A1A1A")
    static let btnPrimaryFg = Color(hex: "FFFFFF")
    
    static let btnSecondaryBg = Color(nsColor: NSColor(name: "btnSecondaryBg", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua 
            ? NSColor(hex: "2F2F2F")
            : NSColor(hex: "F0EFED")
    }))
    
    static let btnSecondaryHover = Color(nsColor: NSColor(name: "btnSecondaryHover", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua 
            ? NSColor(hex: "3A3A3A")
            : NSColor(hex: "E5E3E0")
    }))
    
    // MARK: - Badges
    
    static let badgeVoiceBg = Color(hex: "22C55E").opacity(0.12)
    static let badgeVoiceText = Color(hex: "22C55E")
    static let badgeMusicBg = Color(hex: "3B82F6").opacity(0.12)
    static let badgeMusicText = Color(hex: "3B82F6")
    static let badgeMutedBg = Color(hex: "9A9A9A").opacity(0.12)
    static let badgeMutedText = Color(hex: "9A9A9A")
    
    // No gradients
    static let gradientPrimary = LinearGradient(colors: [Color(hex: "1A1A1A")], startPoint: .leading, endPoint: .trailing)
    static let gradientButton = LinearGradient(colors: [Color(hex: "1A1A1A")], startPoint: .leading, endPoint: .trailing)
    static let gradientSidebarActive = LinearGradient(colors: [Color(hex: "F0EBFF")], startPoint: .leading, endPoint: .trailing)
    static let gradientWarm = LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing)
}


// MARK: - Shadow Modifiers (Soft, like Flow)

extension View {
    func cardShadow() -> some View {
        self
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
            .shadow(color: .black.opacity(0.02), radius: 1, x: 0, y: 1)
    }
    
    func softShadow() -> some View {
        self.shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 1)
    }
    
    func elevatedShadow() -> some View {
        self
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
            .shadow(color: .black.opacity(0.02), radius: 2, x: 0, y: 1)
    }
}
