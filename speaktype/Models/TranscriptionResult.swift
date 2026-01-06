//
//  TranscriptionResult.swift
//  speaktype
//
//  Created on 2026-01-07.
//

import Foundation

/// Represents the result of a transcription operation
struct TranscriptionResult: Identifiable, Codable, Equatable {
    /// Unique identifier for the transcription
    let id: UUID
    
    /// The transcribed text
    var text: String
    
    /// Timestamp when transcription was created
    let timestamp: Date
    
    /// Duration of the audio recording in seconds
    let audioDuration: TimeInterval
    
    /// Confidence score (0.0 to 1.0) if available
    let confidence: Double?
    
    /// Language code (e.g., "en" for English)
    let language: String
    
    /// Model used for transcription (e.g., "base", "small")
    let modelName: String
    
    /// Whether the text has been edited by user
    var isEdited: Bool
    
    /// Error message if transcription failed
    let error: String?
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        text: String,
        timestamp: Date = Date(),
        audioDuration: TimeInterval,
        confidence: Double? = nil,
        language: String = "en",
        modelName: String = "base",
        isEdited: Bool = false,
        error: String? = nil
    ) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.audioDuration = audioDuration
        self.confidence = confidence
        self.language = language
        self.modelName = modelName
        self.isEdited = isEdited
        self.error = error
    }
    
    // MARK: - Computed Properties
    
    /// Whether the transcription was successful
    var isSuccessful: Bool {
        error == nil && !text.isEmpty
    }
    
    /// Formatted duration string
    var formattedDuration: String {
        let minutes = Int(audioDuration) / 60
        let seconds = Int(audioDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// Formatted timestamp string
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    /// Confidence percentage string (if available)
    var confidencePercentage: String? {
        guard let confidence = confidence else { return nil }
        return String(format: "%.1f%%", confidence * 100)
    }
}

// MARK: - Error Result Factory

extension TranscriptionResult {
    /// Creates a result representing an error
    static func error(message: String, audioDuration: TimeInterval = 0) -> TranscriptionResult {
        TranscriptionResult(
            text: "",
            audioDuration: audioDuration,
            error: message
        )
    }
    
    /// Creates an empty result for initialization
    static var empty: TranscriptionResult {
        TranscriptionResult(
            text: "",
            audioDuration: 0
        )
    }
}

