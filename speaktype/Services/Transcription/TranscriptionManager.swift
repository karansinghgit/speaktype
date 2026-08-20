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
    ///
    /// `activeKind` switches *before* the load, not after: the display-state
    /// accessors above read whichever engine `activeKind` names, so setting it
    /// afterwards meant `isLoading` / `loadingStage` reported the idle Whisper
    /// engine for the whole time a Parakeet model was warming up. The recorder
    /// never saw a load in progress and fell back to its truncated status text.
    func loadModel(variant: String) async throws {
        let kind = AIModel.engineKind(for: variant)
        activeKind = kind
        try await engine(for: kind).loadModel(variant: variant)
    }

    // MARK: - Warm-up

    /// Variant whose warm-up is currently in flight, if any. Readable so UI can
    /// show readiness for the specific model it is displaying.
    private(set) var warmingVariant: String?

    /// True while a *background* warm-up is loading a model. Distinct from
    /// `isLoading`, which is true for any load including one the user is
    /// actively waiting on: UI that belongs to a dictation must not react to a
    /// preload the user never asked for.
    private(set) var isWarmingUp = false

    /// Loads `variant` in the background so the first dictation doesn't pay the
    /// model-load cost — the "warming up" wait users hit mid-sentence.
    ///
    /// Fire-and-forget and deduped: warming a model that is already loaded, or
    /// re-warming one already in flight, is a no-op. Only downloaded models are
    /// warmed, because `loadModel` otherwise falls through to FluidAudio's
    /// download path and would silently pull gigabytes with no progress UI.
    ///
    /// - Returns: whether a warm-up was actually started.
    @discardableResult
    func warmUp(variant: String) -> Bool {
        guard !variant.isEmpty else { return false }
        guard warmingVariant != variant else { return false }
        guard !(isInitialized && currentModelVariant == variant) else { return false }
        guard ModelDownloadService.shared.isDownloaded(variant) else { return false }

        warmingVariant = variant
        isWarmingUp = true

        Task { @MainActor in
            do {
                try await self.loadModel(variant: variant)
                print("✅ Warmed up \(variant)")
            } catch {
                // A warm-up is best-effort: the model still loads on demand at
                // the next dictation, which is where errors get surfaced.
                print("⚠️ Warm-up failed for \(variant): \(error.localizedDescription)")
            }
            if self.warmingVariant == variant {
                self.warmingVariant = nil
                self.isWarmingUp = false
            }
        }
        return true
    }

    /// Transcribe an audio file with the currently active engine.
    ///
    /// The raw engine output is passed through the user's dictionary rules so
    /// custom replacements and spoken snippets apply uniformly regardless of
    /// which backend produced the text. Smart trailing punctuation runs last,
    /// after snippets have expanded, so a dictation that resolves to an email,
    /// URL, number, or single token loses the model's sentence-final period.
    func transcribe(audioFile: URL, language: String = "auto") async throws -> String {
        let kind = AIModel.engineKind(for: currentModelVariant)
        let text = try await engine(for: kind).transcribe(audioFile: audioFile, language: language)
        return SmartTrailingPunctuation.apply(to: DictionaryService.apply(to: text))
    }
}

// MARK: - WhisperService conformance

/// `WhisperService` already exposes the full `SpeechToTextEngine` surface, so
/// conformance requires no changes to the Whisper code path.
extension WhisperService: SpeechToTextEngine {}
