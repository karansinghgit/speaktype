//
//  RecordingSession.swift
//  speaktype
//
//  Created on 2026-01-07.
//

import Foundation
import AVFoundation

/// Represents an active or completed audio recording session
struct RecordingSession: Identifiable, Equatable {
    /// Unique identifier for the session
    let id: UUID
    
    /// When the recording started
    let startTime: Date
    
    /// When the recording ended (nil if still recording)
    var endTime: Date?
    
    /// Current or final duration of the recording
    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }
    
    /// Audio format information
    let audioFormat: AudioFormat
    
    /// Temporary file URL where audio is being saved
    let fileURL: URL?
    
    /// Current recording state
    var state: RecordingState
    
    /// Audio level samples for visualization (normalized 0.0 to 1.0)
    var audioLevels: [Float]
    
    /// Error if recording failed
    var error: RecordingError?
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        endTime: Date? = nil,
        audioFormat: AudioFormat = .default,
        fileURL: URL? = nil,
        state: RecordingState = .recording,
        audioLevels: [Float] = [],
        error: RecordingError? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.audioFormat = audioFormat
        self.fileURL = fileURL
        self.state = state
        self.audioLevels = audioLevels
        self.error = error
    }
    
    // MARK: - Computed Properties
    
    /// Whether the recording is currently active
    var isRecording: Bool {
        state == .recording
    }
    
    /// Whether the recording completed successfully
    var isCompleted: Bool {
        state == .completed && error == nil
    }
    
    /// Formatted duration string (MM:SS)
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// Average audio level
    var averageLevel: Float {
        guard !audioLevels.isEmpty else { return 0.0 }
        return audioLevels.reduce(0, +) / Float(audioLevels.count)
    }
    
    /// Peak audio level
    var peakLevel: Float {
        audioLevels.max() ?? 0.0
    }
}

// MARK: - Recording State

/// State of the recording session
enum RecordingState: String, Codable, Equatable {
    /// Recording is in progress
    case recording
    
    /// Recording is paused (future feature)
    case paused
    
    /// Recording completed successfully
    case completed
    
    /// Recording was cancelled
    case cancelled
    
    /// Recording failed with error
    case failed
}

// MARK: - Audio Format

/// Audio format configuration for recording
struct AudioFormat: Equatable, Codable {
    /// Sample rate in Hz
    let sampleRate: Double
    
    /// Number of audio channels
    let channels: Int
    
    /// Bit depth
    let bitDepth: Int
    
    /// Audio format identifier
    let formatID: AudioFormatID
    
    /// Default format optimized for Whisper
    static let `default` = AudioFormat(
        sampleRate: 16000.0, // Whisper expects 16kHz
        channels: 1, // Mono
        bitDepth: 16,
        formatID: kAudioFormatLinearPCM
    )
    
    /// High quality format
    static let highQuality = AudioFormat(
        sampleRate: 48000.0,
        channels: 1,
        bitDepth: 24,
        formatID: kAudioFormatLinearPCM
    )
    
    /// Description of the format
    var description: String {
        "\(Int(sampleRate / 1000))kHz, \(channels)ch, \(bitDepth)-bit"
    }
}

// MARK: - Recording Error

/// Errors that can occur during recording
enum RecordingError: Error, LocalizedError, Equatable {
    case permissionDenied
    case audioEngineFailure
    case fileWriteError
    case maxDurationExceeded
    case audioInputUnavailable
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission is required to record audio."
        case .audioEngineFailure:
            return "Failed to initialize audio recording engine."
        case .fileWriteError:
            return "Failed to save audio recording."
        case .maxDurationExceeded:
            return "Recording stopped: Maximum duration exceeded."
        case .audioInputUnavailable:
            return "No audio input device available."
        case .unknown(let message):
            return "Recording error: \(message)"
        }
    }
}

// MARK: - Factory Methods

extension RecordingSession {
    /// Create a new recording session
    static func new() -> RecordingSession {
        RecordingSession(
            startTime: Date(),
            state: .recording
        )
    }
    
    /// Create a failed session with error
    static func failed(error: RecordingError) -> RecordingSession {
        RecordingSession(
            state: .failed,
            error: error
        )
    }
}

