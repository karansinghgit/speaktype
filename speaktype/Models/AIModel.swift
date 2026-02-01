import SwiftUI

struct AIModel: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let variant: String
    let details: String
    let rating: String
    let size: String
    let speed: Double // Score relative to 10
    let accuracy: Double // Score relative to 10
    let expectedSizeBytes: Int64 // Minimum expected size in bytes for validation
    
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
            accuracy: 9.5, // ~4% WER
            expectedSizeBytes: 1_400_000_000
        ),
        AIModel(
            name: "Whisper Medium",
            variant: "openai_whisper-medium",
            details: "Multilingual • Balanced",
            rating: "Great",
            size: "1.5 GB",
            speed: 5.5,  // Slower due to size
            accuracy: 8.9, // ~6% WER
            expectedSizeBytes: 1_300_000_000
        ),
        AIModel(
            name: "Whisper Small",
            variant: "openai_whisper-small.en",
            details: "English-only • Great Balance",
            rating: "Recommended",
            size: "244 MB",
            speed: 8.0,  // Fast for its accuracy
            accuracy: 8.5, // ~5% WER (English)
            expectedSizeBytes: 200_000_000
        ),
        AIModel(
            name: "Whisper Base",
            variant: "openai_whisper-base.en",
            details: "English-only • Fast & Light",
            rating: "Good",
            size: "74 MB",
            speed: 9.0,  // Very fast
            accuracy: 7.5, // ~7% WER (English)
            expectedSizeBytes: 70_000_000
        ),
        AIModel(
            name: "Whisper Tiny",
            variant: "openai_whisper-tiny",
            details: "Multilingual • Fastest",
            rating: "Basic",
            size: "39 MB",
            speed: 9.5,  // Fastest
            accuracy: 6.0, // ~12% WER
            expectedSizeBytes: 30_000_000
        ),
        
        // MARK: - Parakeet Models (NVIDIA NeMo)
        // Note: Parakeet models require NeMo toolkit support, not WhisperKit
        // These models will appear in the UI but need separate implementation
        AIModel(
            name: "Parakeet TDT 0.6B V3",
            variant: "nvidia/parakeet-tdt-0.6b-v3",
            details: "Multilingual • 25 European Languages • Enhanced Performance",
            rating: "Excellent",
            size: "~600 MB",
            speed: 8.0,
            accuracy: 9.5,
            expectedSizeBytes: 600_000_000
        ),
        AIModel(
            name: "Parakeet TDT 0.6B V2",
            variant: "nvidia/parakeet-tdt-0.6b-v2",
            details: "English • High Accuracy • Timestamps • Punctuation",
            rating: "Excellent",
            size: "~600 MB",
            speed: 7.5,
            accuracy: 9.4,
            expectedSizeBytes: 600_000_000
        )
    ]
    
    /// Returns the expected minimum size for a given model variant
    static func expectedSize(for variant: String) -> Int64 {
        return availableModels.first(where: { $0.variant == variant })?.expectedSizeBytes ?? 50_000_000
    }
    
    var isParakeet: Bool {
        return variant.lowercased().contains("parakeet") || variant.lowercased().contains("nemo")
    }
}
