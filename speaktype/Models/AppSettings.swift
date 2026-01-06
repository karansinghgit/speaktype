//
//  AppSettings.swift
//  speaktype
//
//  Created on 2026-01-07.
//

import Foundation

/// User preferences and application settings
struct AppSettings: Codable, Equatable {
    // MARK: - General Settings
    
    /// Whether to launch app at system startup
    var launchAtLogin: Bool
    
    /// Show status in menu bar
    var showMenuBarStatus: Bool
    
    // MARK: - Transcription Settings
    
    /// Selected Whisper model ("base", "small", "medium", etc.)
    var selectedModel: WhisperModel
    
    /// Language code for transcription
    var language: String
    
    /// Show confidence scores in results
    var showConfidenceScores: Bool
    
    // MARK: - Clipboard Settings
    
    /// Automatically copy transcription to clipboard
    var autoCopyToClipboard: Bool
    
    /// Automatically paste into active application
    var autoPaste: Bool
    
    /// Auto-dismiss result panel after successful paste
    var autoDismissAfterPaste: Bool
    
    /// Delay before auto-dismiss (in seconds)
    var autoDismissDelay: TimeInterval
    
    // MARK: - Audio Settings
    
    /// Maximum recording duration in seconds (safety limit)
    var maxRecordingDuration: TimeInterval
    
    /// Minimum recording duration in seconds (ignore very short recordings)
    var minRecordingDuration: TimeInterval
    
    // MARK: - UI Settings
    
    /// Show waveform visualization while recording
    var showWaveform: Bool
    
    /// Play sound feedback for actions
    var playSoundFeedback: Bool
    
    // MARK: - History Settings
    
    /// Keep transcription history
    var keepHistory: Bool
    
    /// Maximum number of history items to store
    var maxHistoryItems: Int
    
    // MARK: - Default Values
    
    static let `default` = AppSettings(
        launchAtLogin: false,
        showMenuBarStatus: true,
        selectedModel: .base,
        language: "en",
        showConfidenceScores: false,
        autoCopyToClipboard: true,
        autoPaste: false,
        autoDismissAfterPaste: true,
        autoDismissDelay: 3.0,
        maxRecordingDuration: 120.0,
        minRecordingDuration: 0.5,
        showWaveform: true,
        playSoundFeedback: false,
        keepHistory: true,
        maxHistoryItems: 50
    )
}

// MARK: - Whisper Model

/// Available Whisper models for transcription
enum WhisperModel: String, Codable, CaseIterable, Identifiable {
    case tiny
    case base
    case small
    case medium
    case large
    
    var id: String { rawValue }
    
    /// Display name for the model
    var displayName: String {
        rawValue.capitalized
    }
    
    /// Estimated model size in MB
    var estimatedSize: Int {
        switch self {
        case .tiny:
            return 75
        case .base:
            return 140
        case .small:
            return 460
        case .medium:
            return 1500
        case .large:
            return 3000
        }
    }
    
    /// Description of model characteristics
    var description: String {
        switch self {
        case .tiny:
            return "Fastest, lowest accuracy (~75 MB)"
        case .base:
            return "Fast, good accuracy (~140 MB)"
        case .small:
            return "Balanced speed and accuracy (~460 MB)"
        case .medium:
            return "Slower, high accuracy (~1.5 GB)"
        case .large:
            return "Slowest, highest accuracy (~3 GB)"
        }
    }
    
    /// Recommended for MVP
    var isRecommended: Bool {
        self == .base || self == .small
    }
}

