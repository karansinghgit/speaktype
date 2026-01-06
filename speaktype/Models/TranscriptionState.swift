//
//  TranscriptionState.swift
//  speaktype
//
//  Created on 2026-01-07.
//

import Foundation

/// Represents the current state of the transcription process
enum TranscriptionState: String, Codable, Equatable {
    /// App is idle and ready to start recording
    case idle
    
    /// Currently recording audio from microphone
    case listening
    
    /// Processing audio and generating transcription
    case transcribing
    
    /// Transcription complete and ready to display/paste
    case ready
    
    /// An error occurred during the process
    case error
    
    /// Displayable title for the current state
    var title: String {
        switch self {
        case .idle:
            return "Ready"
        case .listening:
            return "Listening..."
        case .transcribing:
            return "Transcribing..."
        case .ready:
            return "Transcription Ready"
        case .error:
            return "Error"
        }
    }
    
    /// Whether the state represents an active operation
    var isActive: Bool {
        switch self {
        case .listening, .transcribing:
            return true
        case .idle, .ready, .error:
            return false
        }
    }
}

