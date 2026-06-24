import Foundation

/// Unified entry point the UI uses for model loading and transcription.
///
/// It routes each call to the correct `SpeechToTextEngine` based on the
/// selected model's `TranscriptionEngineKind`, so views are fully decoupled
/// from any specific backend (Whisper today, Parakeet next).
///
/// Display-state properties mirror the active engine. In Phase 1 the only
/// engine is Whisper, so this is a behavior-preserving pass-through; Phase 2
/// adds the Parakeet engine and switches the state accessors on `activeKind`.
@Observable
class TranscriptionManager {
    static let shared = TranscriptionManager()

    // MARK: - Engines

    private let whisper = WhisperService.shared
    // Phase 2: private let parakeet = ParakeetEngine.shared

    /// Which backend currently owns the loaded model. Drives display state.
    private(set) var activeKind: TranscriptionEngineKind = .whisper

    private init() {}

    /// Resolve the engine responsible for a given engine kind.
    private func engine(for kind: TranscriptionEngineKind) -> any SpeechToTextEngine {
        switch kind {
        case .whisper:
            return whisper
        case .parakeet:
            // Phase 2 wires the Parakeet engine here. Until then, Parakeet
            // models are not present in the catalog so this is unreachable.
            return whisper
        }
    }

    // MARK: - Display state
    //
    // Phase 1 reads the Whisper engine directly (the only backend), which keeps
    // SwiftUI observation tracking on the concrete `@Observable` instance.
    // Phase 2 will switch these on `activeKind`.

    var isInitialized: Bool { whisper.isInitialized }
    var isLoading: Bool { whisper.isLoading }
    var isTranscribing: Bool { whisper.isTranscribing }
    var loadingStage: String { whisper.loadingStage }
    var currentModelVariant: String { whisper.currentModelVariant }

    // MARK: - Actions

    /// Load the engine's saved/default model (mirrors `WhisperService.initialize`).
    func initialize() async throws {
        try await whisper.initialize()
    }

    /// Load a specific model variant, routing to its owning engine.
    func loadModel(variant: String) async throws {
        let kind = AIModel.engineKind(for: variant)
        try await engine(for: kind).loadModel(variant: variant)
        activeKind = kind
    }

    /// Transcribe an audio file with the currently active engine.
    func transcribe(audioFile: URL, language: String = "auto") async throws -> String {
        let kind = AIModel.engineKind(for: currentModelVariant)
        return try await engine(for: kind).transcribe(audioFile: audioFile, language: language)
    }
}

// MARK: - WhisperService conformance

/// `WhisperService` already exposes the full `SpeechToTextEngine` surface, so
/// conformance requires no changes to the Whisper code path.
extension WhisperService: SpeechToTextEngine {}
