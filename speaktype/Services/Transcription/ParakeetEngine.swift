import Foundation
import FluidAudio

/// Maps SpeakType catalog variants to FluidAudio model versions.
///
/// Keeping this in one place lets both the engine (loading) and the model
/// store (download / delete / existence checks) agree on which FluidAudio
/// model a given catalog variant refers to.
enum ParakeetCatalog {
    static let v3Variant = "parakeet-tdt-0.6b-v3"
    static let v2Variant = "parakeet-tdt-0.6b-v2"

    /// All Parakeet variants SpeakType ships, newest first.
    static let variants = [v3Variant, v2Variant]

    /// FluidAudio model version for a given catalog variant.
    static func version(for variant: String) -> AsrModelVersion {
        switch variant {
        case v2Variant: return .v2
        default: return .v3
        }
    }
}

/// Speech-to-text engine backed by NVIDIA Parakeet, run on-device via
/// FluidAudio (CoreML / Apple Neural Engine).
///
/// Conforms to `SpeechToTextEngine` so `TranscriptionManager` can use it
/// interchangeably with `WhisperService`. State mirrors the Whisper engine's
/// surface so the existing UI works unchanged.
@Observable
class ParakeetEngine: SpeechToTextEngine {
    static let shared = ParakeetEngine()

    var isInitialized = false
    var isTranscribing = false
    var isLoading = false
    var loadingStage = ""
    var currentModelVariant = ""

    /// FluidAudio's actor that owns the loaded CoreML models.
    private var manager: AsrManager?

    private init() {}

    func loadModel(variant: String) async throws {
        // Already loaded this exact model.
        if isInitialized, currentModelVariant == variant, manager != nil { return }

        isLoading = true
        isInitialized = false
        loadingStage = "Preparing Parakeet model…"
        defer { isLoading = false }

        // Release any previously loaded model before loading a new one.
        if let manager {
            await manager.cleanup()
        }
        manager = nil

        let version = ParakeetCatalog.version(for: variant)
        loadingStage = "Loading Parakeet model…"

        // Downloads from Hugging Face on first use, then loads from cache.
        let models = try await AsrModels.downloadAndLoad(version: version)
        let manager = AsrManager(config: .default)
        try await manager.loadModels(models)

        self.manager = manager
        currentModelVariant = variant
        isInitialized = true
        loadingStage = ""
    }

    func transcribe(audioFile: URL, language: String) async throws -> String {
        guard let manager else { throw ASRError.notInitialized }

        isTranscribing = true
        defer { isTranscribing = false }

        // One-shot (batch) transcription: a fresh decoder state per file.
        // `language: nil` lets the multilingual model auto-detect.
        var decoderState = try TdtDecoderState()
        let result = try await manager.transcribe(audioFile, decoderState: &decoderState)
        return result.text
    }
}
