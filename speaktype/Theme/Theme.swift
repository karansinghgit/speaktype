//
//  Theme.swift
//  speaktype
//
//  Clean, minimal design system
//  Sharp lines, no rounded corners, professional
//

import SwiftUI

// MARK: - Theme Environment Key

struct ThemeKey: EnvironmentKey {
    static let defaultValue: SpeakTypeTheme = .light
}

extension EnvironmentValues {
    var theme: SpeakTypeTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - SpeakType Theme

enum SpeakTypeTheme {
    case light
    case dark
    
    // MARK: - Semantic Colors
    
    var background: Color {
        switch self {
        case .light: return Color(hex: "FAFAF8")
        case .dark: return Color(hex: "1C1C1E")
        }
    }
    
    var surface: Color {
        switch self {
        case .light: return .white
        case .dark: return Color(hex: "2C2C2E")
        }
    }
    
    var textPrimary: Color {
        switch self {
        case .light: return Color(hex: "1C1C1E")
        case .dark: return .white
        }
    }
    
    var textSecondary: Color {
        switch self {
        case .light: return Color(hex: "6E6E73")
        case .dark: return Color(hex: "A0A0A5")
        }
    }
    
    var border: Color {
        switch self {
        case .light: return Color(hex: "E5E5E3")
        case .dark: return Color(hex: "3A3A3C")
        }
    }
    
    var accent: Color {
        return Color(hex: "2C2C54")
    }
}

// MARK: - Theme Provider

struct ThemeProvider<Content: View>: View {
    @Environment(\.colorScheme) var systemColorScheme
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    private var activeTheme: SpeakTypeTheme {
        switch appTheme {
        case .light: return .light
        case .dark: return .dark
        case .system: return systemColorScheme == .dark ? .dark : .light
        }
    }
    
    var body: some View {
        content
            .environment(\.theme, activeTheme)
    }
}

// MARK: - View Modifier

extension View {
    func themed() -> some View {
        ThemeProvider { self }
    }
}

// MARK: - Clean Card Style

extension View {
    func cleanCard(theme: SpeakTypeTheme) -> some View {
        self
            .background(theme.surface)
            .overlay(
                Rectangle()
                    .stroke(theme.border, lineWidth: 1)
            )
    }
}
