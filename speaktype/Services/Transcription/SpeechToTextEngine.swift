import Foundation

/// A speech-to-text backend that can load a model and transcribe audio.
///
/// Both the Whisper (`WhisperService`) and Parakeet engines conform to this so
/// that `TranscriptionManager` can treat them interchangeably. Conformers are
/// expected to be `@Observable` reference types so the UI can react to changes
/// in their loading / transcription state.
///
/// All state properties mirror the existing `WhisperService` surface so the
/// abstraction is a drop-in: nothing about the Whisper code path changes.
protocol SpeechToTextEngine: AnyObject {
    /// True once a model is loaded and ready to transcribe.
    var isInitialized: Bool { get }

    /// True while a model is being loaded into memory.
    var isLoading: Bool { get }

    /// True while a transcription is actively running.
    var isTranscribing: Bool { get }

    /// Human-readable description of the current loading stage (for the UI).
    var loadingStage: String { get }

    /// The variant identifier of the currently loaded model (empty if none).
    var currentModelVariant: String { get }

    /// Load the given model variant into memory, replacing any current model.
    func loadModel(variant: String) async throws

    /// Transcribe an audio file and return the normalized text.
    /// - Parameter language: BCP-47 language code, or `"auto"` to detect.
    func transcribe(audioFile: URL, language: String) async throws -> String
}
