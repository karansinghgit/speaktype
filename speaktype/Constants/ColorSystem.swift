import SwiftUI

// MARK: - SpeakType Color System

extension Color {
    // MARK: - Core Background Layers
    static let bgApp = Color(hex: "0E0F12")
    static let bgSidebar = Color(hex: "121318")
    static let bgSurface = Color(hex: "16171C")
    static let bgCard = Color(hex: "1C1E24")
    static let bgHover = Color(hex: "242632")
    
    // MARK: - Borders & Dividers
    static let borderSubtle = Color(hex: "2A2D36")
    static let borderCard = Color.white.opacity(0.04)
    static let borderActive = Color(hex: "4DA3FF").opacity(0.35)
    
    // MARK: - Accent Colors
    static let accentRed = Color(hex: "FF4D4D")
    static let accentRedSoft = Color(hex: "FF4D4D").opacity(0.15)
    static let accentBlue = Color(hex: "4DA3FF")
    static let accentBlueSoft = Color(hex: "4DA3FF").opacity(0.15)
    
    // MARK: - Text Colors
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "B6BAC7")
    static let textMuted = Color(hex: "8A8F9C")
    static let textDisabled = Color(hex: "5E636E")
    
    // MARK: - Sidebar Colors
    static let sidebarItem = Color(hex: "C8CCD8")
    static let sidebarItemHoverBg = Color(hex: "1E2028")
    
    // MARK: - Button Colors
    static let btnSecondaryBg = Color(hex: "2A2D36")
    static let btnSecondaryHover = Color(hex: "323644")
    
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
