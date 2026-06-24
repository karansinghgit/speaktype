import SwiftUI

struct AIModel: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let variant: String
    let details: String
    let rating: String
    let size: String
    let speed: Double  // Score relative to 10
    let accuracy: Double  // Score relative to 10
    let expectedSizeBytes: Int64  // Minimum expected size in bytes for validation
    let minimumRAMGB: Int  // Minimum device RAM in GB for reliable loading
    /// Which backend runs this model. Defaults to `.whisper` so existing
    /// catalog entries and call sites are unaffected. (Declared `var` so it is
    /// part of the synthesized memberwise initializer with a default.)
    var engine: TranscriptionEngineKind = .whisper
    /// Explicit English-only flag for engines that don't encode it in the
    /// variant name (e.g. Parakeet). When nil, falls back to the Whisper
    /// `.en` suffix convention.
    var englishOnlyOverride: Bool? = nil

    var languageSupportLabel: String {
        isEnglishOnly ? "English-only" : "Multilingual"
    }

    var isEnglishOnly: Bool {
        englishOnlyOverride ?? variant.hasSuffix(".en")
    }

    // Speed/Accuracy based on OpenAI Whisper benchmarks (WER on LibriSpeech test-clean)
    // Speed: relative performance on Apple Silicon (10 = fastest)
    // Accuracy: based on Word Error Rate (10 = ~2% WER, 5 = ~15% WER)
    static let availableModels: [AIModel] = [
        AIModel(
            name: "Whisper Large v3 Turbo",
            variant: "openai_whisper-large-v3_turbo",
            details: "Multilingual • Best Accuracy • Optimized",
            rating: "Excellent",
            size: "1.6 GB",
            speed: 7.0,  // Optimized but still large
            accuracy: 9.5,  // ~4% WER
            expectedSizeBytes: 1_400_000_000,
            minimumRAMGB: 8
        ),
        AIModel(
            name: "Whisper Medium",
            variant: "openai_whisper-medium",
            details: "Multilingual • Balanced",
            rating: "Great",
            size: "1.5 GB",
            speed: 5.5,  // Slower due to size
            accuracy: 8.9,  // ~6% WER
            expectedSizeBytes: 1_300_000_000,
            minimumRAMGB: 8
        ),
        AIModel(
            name: "Whisper Small",
            variant: "openai_whisper-small.en",
            details: "English-only • Great Balance",
            rating: "Recommended",
            size: "244 MB",
            speed: 8.0,  // Fast for its accuracy
            accuracy: 8.5,  // ~5% WER (English)
            expectedSizeBytes: 200_000_000,
            minimumRAMGB: 4
        ),
        AIModel(
            name: "Whisper Base",
            variant: "openai_whisper-base.en",
            details: "English-only • Fast & Light",
            rating: "Good",
            size: "74 MB",
            speed: 9.0,  // Very fast
            accuracy: 7.5,  // ~7% WER (English)
            expectedSizeBytes: 70_000_000,
            minimumRAMGB: 2
        ),
        AIModel(
            name: "Whisper Tiny",
            variant: "openai_whisper-tiny",
            details: "Multilingual • Fastest",
            rating: "Basic",
            size: "39 MB",
            speed: 9.5,  // Fastest
            accuracy: 6.0,  // ~12% WER
            expectedSizeBytes: 30_000_000,
            minimumRAMGB: 2
        ),
        // NVIDIA Parakeet (run on-device via FluidAudio / CoreML).
        // Transducer (TDT) models: much faster than Whisper at similar accuracy.
        // Download size is approximate (FluidAudio fetches the int8 weight set).
        AIModel(
            name: "Parakeet TDT v3",
            variant: ParakeetCatalog.v3Variant,
            details: "Multilingual (25 languages) • Very fast • NVIDIA Parakeet",
            rating: "Excellent",
            size: "~2 GB",
            speed: 9.7,
            accuracy: 9.2,
            expectedSizeBytes: 500_000_000,
            minimumRAMGB: 4,
            engine: .parakeet
        ),
        AIModel(
            name: "Parakeet TDT v2",
            variant: ParakeetCatalog.v2Variant,
            details: "English-only • Fastest • Highest English recall",
            rating: "Excellent",
            size: "~2 GB",
            speed: 9.8,
            accuracy: 9.1,
            expectedSizeBytes: 500_000_000,
            minimumRAMGB: 4,
            engine: .parakeet,
            englishOnlyOverride: true
        ),
        AIModel(
            name: "Parakeet TDT-CTC 110M",
            variant: ParakeetCatalog.ctc110mVariant,
            details: "English-only • Tiny & fast • Small download",
            rating: "Great",
            size: "~450 MB",
            speed: 9.9,
            accuracy: 8.5,
            expectedSizeBytes: 200_000_000,
            minimumRAMGB: 2,
            engine: .parakeet,
            englishOnlyOverride: true
        ),
    ]

    /// Returns the expected minimum size for a given model variant
    static func expectedSize(for variant: String) -> Int64 {
        return availableModels.first(where: { $0.variant == variant })?.expectedSizeBytes
            ?? 50_000_000
    }

    /// Returns which backend owns a given model variant.
    /// Defaults to `.whisper` for unknown variants so existing behavior is preserved.
    static func engineKind(for variant: String) -> TranscriptionEngineKind {
        return availableModels.first(where: { $0.variant == variant })?.engine ?? .whisper
    }

    /// All models for a given engine.
    static func models(for engine: TranscriptionEngineKind) -> [AIModel] {
        availableModels.filter { $0.engine == engine }
    }

    /// Returns the best model recommended for this device's RAM
    static func recommendedModel(forDeviceRAMGB ram: Int) -> AIModel {
        // Find the best (highest accuracy) model that fits in the device's RAM
        return availableModels.first(where: { ram >= $0.minimumRAMGB })
            ?? availableModels.last!  // Fallback to smallest
    }

    /// Returns a warning string if this model may not work well on the device, nil otherwise
    func ramWarning(deviceRAMGB: Int) -> String? {
        guard deviceRAMGB < minimumRAMGB else { return nil }
        return "Requires \(minimumRAMGB)GB+ RAM — your Mac has \(deviceRAMGB)GB"
    }
}
