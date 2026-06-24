import Foundation

/// Identifies which speech-to-text backend powers a given model.
///
/// Each `AIModel` is tagged with one of these so the app can route model
/// loading, downloading and transcription to the correct engine without the
/// UI needing to know any backend-specific details.
enum TranscriptionEngineKind: String, Codable, CaseIterable {
    /// OpenAI Whisper models, run on-device via WhisperKit / CoreML.
    case whisper

    /// NVIDIA Parakeet models, run on-device via FluidAudio / CoreML.
    case parakeet

    /// Human-readable label for UI badges.
    var displayName: String {
        switch self {
        case .whisper: return "Whisper"
        case .parakeet: return "Parakeet"
        }
    }
}
