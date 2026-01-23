//
//  Typography.swift
//  speaktype
//
//  Mixed typography system - Serif for headlines, Sans for body
//  Inspired by Wispr Flow's typographic variety
//

import SwiftUI

// MARK: - Typography System

enum Typography {
    
    // MARK: - Serif Headlines (like Flow's editorial headers)
    // Using New York (Apple's serif) or Georgia fallback
    
    static let displayLarge = Font.system(size: 32, weight: .medium, design: .serif)
    static let displayMedium = Font.system(size: 26, weight: .medium, design: .serif)
    static let displaySmall = Font.system(size: 22, weight: .medium, design: .serif)
    
    // MARK: - Sans Headlines (section headers)
    
    static let headlineLarge = Font.system(size: 18, weight: .semibold)
    static let headlineMedium = Font.system(size: 16, weight: .semibold)
    static let headlineSmall = Font.system(size: 14, weight: .semibold)
    
    // MARK: - Titles (UI elements)
    
    static let titleLarge = Font.system(size: 15, weight: .medium)
    static let titleMedium = Font.system(size: 14, weight: .medium)
    static let titleSmall = Font.system(size: 13, weight: .medium)
    
    // MARK: - Body
    
    static let bodyLarge = Font.system(size: 15)
    static let bodyMedium = Font.system(size: 14)
    static let bodySmall = Font.system(size: 13)
    
    // MARK: - Labels & UI
    
    static let labelLarge = Font.system(size: 14, weight: .medium)
    static let labelMedium = Font.system(size: 13, weight: .medium)
    static let labelSmall = Font.system(size: 12, weight: .medium)
    
    // MARK: - Captions
    
    static let caption = Font.system(size: 12)
    static let captionSmall = Font.system(size: 11)
    static let captionBold = Font.system(size: 11, weight: .semibold)
    
    // MARK: - Special
    
    static let mono = Font.system(size: 13, design: .monospaced)
    static let monoSmall = Font.system(size: 11, design: .monospaced)
    static let statValue = Font.system(size: 40, weight: .medium, design: .serif)
    static let statLabel = Font.system(size: 13)
    static let badge = Font.system(size: 11, weight: .medium)
    
    // MARK: - Sidebar
    
    static let sidebarItem = Font.system(size: 14, weight: .medium)
    static let sidebarLabel = Font.system(size: 11, weight: .medium)
}
