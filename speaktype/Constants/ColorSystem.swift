import SwiftUI

// MARK: - SpeakType Color System

extension Color {
    // MARK: - Core Background Layers
    static let bgApp = Color(nsColor: NSColor(name: "bgApp", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: "0E0F12") : NSColor(hex: "F2F4F8")
    }))
    
    static let bgSidebar = Color(nsColor: NSColor(name: "bgSidebar", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: "121318") : NSColor(hex: "FFFFFF")
    }))
    
    static let bgSurface = Color(nsColor: NSColor(name: "bgSurface", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: "16171C") : NSColor(hex: "FFFFFF")
    }))
    
    static let bgCard = Color(nsColor: NSColor(name: "bgCard", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: "1C1E24") : NSColor(hex: "FFFFFF")
    }))
    
    static let bgHover = Color(nsColor: NSColor(name: "bgHover", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: "242632") : NSColor(hex: "E8EAF0")
    }))
    
    // MARK: - Borders & Dividers
    static let borderSubtle = Color(nsColor: NSColor(name: "borderSubtle", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: "2A2D36") : NSColor(hex: "E0E0E0")
    }))
    
    static let borderCard = Color(nsColor: NSColor(name: "borderCard", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor.white.withAlphaComponent(0.04) : NSColor.black.withAlphaComponent(0.05)
    }))
    
    static let borderActive = Color(hex: "4DA3FF").opacity(0.35)
    
    // MARK: - Accent Colors
    static let accentRed = Color(hex: "FF4D4D")
    static let accentRedSoft = Color(hex: "FF4D4D").opacity(0.15)
    static let accentBlue = Color(hex: "4DA3FF")
    static let accentBlueSoft = Color(hex: "4DA3FF").opacity(0.15)
    
    // MARK: - Text Colors
    static let textPrimary = Color(nsColor: NSColor(name: "textPrimary", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor.white : NSColor(hex: "1A1C20")
    }))
    
    static let textSecondary = Color(nsColor: NSColor(name: "textSecondary", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: "B6BAC7") : NSColor(hex: "6B7280")
    }))
    
    static let textMuted = Color(nsColor: NSColor(name: "textMuted", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: "8A8F9C") : NSColor(hex: "9CA3AF")
    }))
    
    static let textDisabled = Color(nsColor: NSColor(name: "textDisabled", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: "5E636E") : NSColor(hex: "D1D5DB")
    }))
    
    // MARK: - Sidebar Colors
    static let sidebarItem = Color(nsColor: NSColor(name: "sidebarItem", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: "C8CCD8") : NSColor(hex: "4B5563")
    }))
    
    static let sidebarItemHoverBg = Color(nsColor: NSColor(name: "sidebarItemHoverBg", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: "1E2028") : NSColor(hex: "F3F4F6")
    }))
    
    // MARK: - Button Colors
    static let btnSecondaryBg = Color(nsColor: NSColor(name: "btnSecondaryBg", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: "2A2D36") : NSColor(hex: "E5E7EB")
    }))
    
    static let btnSecondaryHover = Color(nsColor: NSColor(name: "btnSecondaryHover", dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: "323644") : NSColor(hex: "D1D5DB")
    }))
    
    // MARK: - Badge Colors
    static let badgeVoiceBg = Color(hex: "FF4D4D").opacity(0.15)
    static let badgeVoiceText = Color(hex: "FF4D4D")
    static let badgeMusicBg = Color(hex: "4DA3FF").opacity(0.15)
    static let badgeMusicText = Color(hex: "4DA3FF")
    static let badgeMutedBg = Color(hex: "8A8F9C").opacity(0.15)
    static let badgeMutedText = Color(hex: "8A8F9C")
    
    // MARK: - Gradients
    static let gradientPrimary = LinearGradient(
        colors: [Color(hex: "FF4D4D"), Color(hex: "FF6A6A"), Color(hex: "4DA3FF")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let gradientButton = LinearGradient(
        colors: [Color(hex: "FF4D4D"), Color(hex: "4DA3FF")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let gradientSidebarActive = LinearGradient(
        colors: [
            Color(hex: "FF4D4D").opacity(0.25),
            Color(hex: "4DA3FF").opacity(0.25)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}


// MARK: - Shadow Modifiers

extension View {
    func cardShadow() -> some View {
        self.shadow(color: .black.opacity(0.45), radius: 16, x: 0, y: 12)
    }
    
    func softShadow() -> some View {
        self.shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 8)
    }
}
