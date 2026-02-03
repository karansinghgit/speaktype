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
    
    static let availableModels: [AIModel] = [
        AIModel(
            name: "Whisper Large v3 Turbo",
            variant: "openai_whisper-large-v3_turbo",
            details: "Multilingual • High Accuracy • Fast",
            rating: "Excellent",
            size: "1.6 GB",
            speed: 8.5,
            accuracy: 9.7,
            expectedSizeBytes: 1_400_000_000 // ~1.4GB minimum
        ),
        AIModel(
            name: "Whisper Medium",
            variant: "openai_whisper-medium",
            details: "Multilingual • Balanced",
            rating: "Great",
            size: "1.5 GB",
            speed: 5.0,
            accuracy: 9.4,
            expectedSizeBytes: 1_300_000_000 // ~1.3GB minimum
        ),
        AIModel(
            name: "Whisper Base",
            variant: "openai_whisper-base.en",
            details: "English-only • Optimized for Apple Silicon",
            rating: "Standard",
            size: "74 MB",
            speed: 9.0,
            accuracy: 8.0,
            expectedSizeBytes: 70_000_000 // ~70MB minimum
        ),
        AIModel(
            name: "Whisper Small",
            variant: "openai_whisper-small.en",
            details: "English-only • Higher accuracy",
            rating: "Good",
            size: "244 MB",
            speed: 7.5,
            accuracy: 8.9,
            expectedSizeBytes: 200_000_000 // ~200MB minimum
        ),
        AIModel(
            name: "Whisper Tiny",
            variant: "openai_whisper-tiny",
            details: "Multilingual • Fastest",
            rating: "Basic",
            size: "39 MB",
            speed: 9.8,
            accuracy: 7.2,
            expectedSizeBytes: 30_000_000 // ~30MB minimum
        )
    ]
    
    /// Returns the expected minimum size for a given model variant
    static func expectedSize(for variant: String) -> Int64 {
        return availableModels.first(where: { $0.variant == variant })?.expectedSizeBytes ?? 50_000_000
    }
}
