//
//  LicenseManager+Extensions.swift
//  speaktype
//
//  Created on 2026-01-19.
//  Convenient extensions for feature gating
//

import Foundation

extension LicenseManager {
    
    /// Check if a specific pro feature is available
    /// - Parameter feature: The feature to check
    /// - Returns: True if the user has Pro access
    func hasAccess(to feature: ProFeature) -> Bool {
        return isPro
    }
    
    /// Get user-friendly license status text
    var licenseStatusText: String {
        if isPro {
            if let expirationDate = expirationDate {
                return "Pro (expires \(expirationDate.formatted(date: .abbreviated, time: .omitted)))"
            }
            return "Pro (lifetime)"
        }
        return "Free"
    }
    
    /// Check if license is expiring soon (within 30 days)
    var isExpiringSoon: Bool {
        guard let expirationDate = expirationDate else { return false }
        let thirtyDaysFromNow = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        return expirationDate < thirtyDaysFromNow && expirationDate > Date()
    }
    
    /// Days until license expires
    var daysUntilExpiration: Int? {
        guard let expirationDate = expirationDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day
    }
}

// MARK: - Pro Features Enum

/// Define all Pro features in your app here
enum ProFeature {
    case advancedAIModels
    case customDictionary
    case cloudSync
    case exportFormats
    case unlimitedHistory
    case customShortcuts
    case darkMode
    case voiceProfiles
    
    var displayName: String {
        switch self {
        case .advancedAIModels: return "Advanced AI Models"
        case .customDictionary: return "Custom Dictionary"
        case .cloudSync: return "Cloud Sync"
        case .exportFormats: return "Export Formats"
        case .unlimitedHistory: return "Unlimited History"
        case .customShortcuts: return "Custom Shortcuts"
        case .darkMode: return "Dark Mode"
        case .voiceProfiles: return "Voice Profiles"
        }
    }
    
    var description: String {
        switch self {
        case .advancedAIModels:
            return "Access GPT-4, Claude, and other premium models"
        case .customDictionary:
            return "Add custom words and phrases for better recognition"
        case .cloudSync:
            return "Sync your settings and history across devices"
        case .exportFormats:
            return "Export transcriptions in PDF, Word, and more"
        case .unlimitedHistory:
            return "Keep unlimited transcription history"
        case .customShortcuts:
            return "Create custom keyboard shortcuts"
        case .darkMode:
            return "Beautiful dark mode interface"
        case .voiceProfiles:
            return "Train custom voice profiles for better accuracy"
        }
    }
    
    var icon: String {
        switch self {
        case .advancedAIModels: return "brain"
        case .customDictionary: return "book.closed"
        case .cloudSync: return "icloud"
        case .exportFormats: return "square.and.arrow.up"
        case .unlimitedHistory: return "clock"
        case .customShortcuts: return "command"
        case .darkMode: return "moon.stars"
        case .voiceProfiles: return "waveform"
        }
    }
}

