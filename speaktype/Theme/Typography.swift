//
//  Typography.swift
//  speaktype
//
//  Typography system using Source Sans 3 for UI and system serif for headers
//

import SwiftUI

// MARK: - Font Names

private enum FontName {
    static let sourceSans = "SourceSans3-Regular"
}

// MARK: - Typography System

enum Typography {
    
    // MARK: - Display Headlines (Serif - editorial feel)
    
    static let displayLarge = Font.system(size: 32, weight: .medium, design: .serif)
    static let displayMedium = Font.system(size: 26, weight: .medium, design: .serif)
    static let displaySmall = Font.system(size: 22, weight: .medium, design: .serif)
    
    // MARK: - Headlines (Source Sans Bold)
    
    static let headlineLarge = Font.custom(FontName.sourceSans, size: 18).weight(.bold)
    static let headlineMedium = Font.custom(FontName.sourceSans, size: 16).weight(.semibold)
    static let headlineSmall = Font.custom(FontName.sourceSans, size: 14).weight(.semibold)
    
    // MARK: - Titles (Source Sans Medium)
    
    static let titleLarge = Font.custom(FontName.sourceSans, size: 15).weight(.medium)
    static let titleMedium = Font.custom(FontName.sourceSans, size: 14).weight(.medium)
    static let titleSmall = Font.custom(FontName.sourceSans, size: 13).weight(.medium)
    
    // MARK: - Body (Source Sans Regular)
    
    static let bodyLarge = Font.custom(FontName.sourceSans, size: 15).weight(.regular)
    static let bodyMedium = Font.custom(FontName.sourceSans, size: 14).weight(.regular)
    static let bodySmall = Font.custom(FontName.sourceSans, size: 13).weight(.regular)
    
    // MARK: - Labels (Source Sans Medium)
    
    static let labelLarge = Font.custom(FontName.sourceSans, size: 14).weight(.medium)
    static let labelMedium = Font.custom(FontName.sourceSans, size: 13).weight(.medium)
    static let labelSmall = Font.custom(FontName.sourceSans, size: 12).weight(.medium)
    
    // MARK: - Captions (Source Sans Light/Regular)
    
    static let caption = Font.custom(FontName.sourceSans, size: 12).weight(.regular)
    static let captionSmall = Font.custom(FontName.sourceSans, size: 11).weight(.regular)
    static let captionBold = Font.custom(FontName.sourceSans, size: 11).weight(.semibold)
    
    // MARK: - Special
    
    static let mono = Font.system(size: 13, design: .monospaced)
    static let monoSmall = Font.system(size: 11, design: .monospaced)
    static let statValue = Font.system(size: 40, weight: .medium, design: .serif)
    static let statLabel = Font.custom(FontName.sourceSans, size: 13).weight(.regular)
    
    static let badge = Font.custom(FontName.sourceSans, size: 11).weight(.medium)
    
    // MARK: - Card Typography (Source Sans - clean cards)
    
    static let cardTitle = Font.custom(FontName.sourceSans, size: 17).weight(.semibold)
    static let cardSubtitle = Font.custom(FontName.sourceSans, size: 14).weight(.regular)
    static let cardMeta = Font.custom(FontName.sourceSans, size: 12).weight(.light)
    static let cardMetaBold = Font.custom(FontName.sourceSans, size: 12).weight(.medium)
    static let cardDescription = Font.custom(FontName.sourceSans, size: 13).weight(.regular)
    static let buttonLabel = Font.custom(FontName.sourceSans, size: 13).weight(.semibold)
    static let buttonLabelSmall = Font.custom(FontName.sourceSans, size: 12).weight(.medium)
    
    // MARK: - Sidebar (Source Sans)
    
    static let sidebarLogo = Font.custom(FontName.sourceSans, size: 16).weight(.bold)
    static let sidebarItem = Font.custom(FontName.sourceSans, size: 14).weight(.regular)
    static let sidebarItemActive = Font.custom(FontName.sourceSans, size: 14).weight(.semibold)
    static let sidebarBadge = Font.custom(FontName.sourceSans, size: 10).weight(.medium)
    static let sidebarPromoTitle = Font.custom(FontName.sourceSans, size: 13).weight(.semibold)
    static let sidebarPromoSubtitle = Font.custom(FontName.sourceSans, size: 12).weight(.regular)
    static let sidebarPromoButton = Font.custom(FontName.sourceSans, size: 12).weight(.medium)
}
