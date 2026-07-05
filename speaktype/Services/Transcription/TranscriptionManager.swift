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
    private let parakeet = ParakeetEngine.shared

    /// Which backend currently owns the loaded model. Drives display state.
    private(set) var activeKind: TranscriptionEngineKind = .whisper

    private init() {}

    /// Resolve the engine responsible for a given engine kind.
    private func engine(for kind: TranscriptionEngineKind) -> any SpeechToTextEngine {
        switch kind {
        case .whisper:
            return whisper
        case .parakeet:
            return parakeet
        }
    }

    // MARK: - Display state
    //
    // These switch on `activeKind` and read the concrete `@Observable` engine
    // directly so SwiftUI observation tracks the active backend's state.

    var isInitialized: Bool {
        switch activeKind {
        case .whisper: return whisper.isInitialized
        case .parakeet: return parakeet.isInitialized
        }
    }
    var isLoading: Bool {
        switch activeKind {
        case .whisper: return whisper.isLoading
        case .parakeet: return parakeet.isLoading
        }
    }
    var isTranscribing: Bool {
        switch activeKind {
        case .whisper: return whisper.isTranscribing
        case .parakeet: return parakeet.isTranscribing
        }
    }
    var loadingStage: String {
        switch activeKind {
        case .whisper: return whisper.loadingStage
        case .parakeet: return parakeet.loadingStage
        }
    }
    /// When the in-flight model load began (Whisper only), for elapsed-time UI.
    var loadingStartedAt: Date? {
        switch activeKind {
        case .whisper: return whisper.loadingStartedAt
        case .parakeet: return nil
        }
    }
    var currentModelVariant: String {
        switch activeKind {
        case .whisper: return whisper.currentModelVariant
        case .parakeet: return parakeet.currentModelVariant
        }
    }

    // MARK: - Actions

    /// Load the engine's saved/default model (mirrors `WhisperService.initialize`).
    ///
    /// Whisper restores its previously selected model; Parakeet is always
    /// loaded explicitly via `loadModel`, so there is nothing to restore for it.
    func initialize() async throws {
        if activeKind == .whisper {
            try await whisper.initialize()
        }
    }

    /// Load a specific model variant, routing to its owning engine.
    func loadModel(variant: String) async throws {
        guard let kind = AIModel.engineKind(for: variant) else {
            throw WhisperService.TranscriptionError.unsupportedModelVariant
        }
        try await engine(for: kind).loadModel(variant: variant)
        activeKind = kind
    }

    /// Release the active in-memory model if its downloaded files were removed.
    func unloadModelIfCurrent(variant: String) async {
        let wasActive = currentModelVariant == variant

        await whisper.unloadModelIfCurrent(variant: variant)
        await parakeet.unloadModelIfCurrent(variant: variant)

        if wasActive {
            activeKind = .whisper
        }
    }

    /// Transcribe an audio file with the currently active engine.
    func transcribe(audioFile: URL, language: String = "auto") async throws -> String {
        guard let kind = AIModel.engineKind(for: currentModelVariant) else {
            throw WhisperService.TranscriptionError.unsupportedModelVariant
        }
        return try await engine(for: kind).transcribe(audioFile: audioFile, language: language)
    }
}

// MARK: - WhisperService conformance

/// `WhisperService` already exposes the full `SpeechToTextEngine` surface, so
/// conformance requires no changes to the Whisper code path.
extension WhisperService: SpeechToTextEngine {}
