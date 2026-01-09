import SwiftUI

struct AIModel: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let variant: String
    let details: String
    let rating: String
    let size: String
    
    static let availableModels: [AIModel] = [
        AIModel(
            name: "Distil-Whisper Large v3",
            variant: "distil-whisper/distil-large-v3",
            details: "English • High Quality • Fast",
            rating: "Excellent",
            size: "756 MB"
        ),
        AIModel(
            name: "Whisper Large v3",
            variant: "openai/whisper-large-v3",
            details: "Multilingual • Best Accuracy • Slower",
            rating: "Best",
            size: "3.1 GB"
        ),
        AIModel(
            name: "Whisper Medium",
            variant: "openai/whisper-medium",
            details: "Multilingual • Balanced",
            rating: "Great",
            size: "1.5 GB"
        ),
        AIModel(
            name: "Distil-Whisper Medium",
            variant: "distil-whisper/distil-medium.en",
            details: "English-only • Fast • Good Accuracy",
            rating: "Good",
            size: "396 MB"
        ),
        AIModel(
            name: "Whisper Base",
            variant: "openai_whisper-base",
            details: "English-only • Optimized for Apple Silicon",
            rating: "Standard",
            size: "74 MB"
        ),
        AIModel(
            name: "Whisper Small",
            variant: "openai_whisper-small",
            details: "English-only • Higher accuracy",
            rating: "Good",
            size: "244 MB"
        ),
        AIModel(
            name: "Whisper Tiny",
            variant: "openai_whisper-tiny",
            details: "Multilingual • Fastest",
            rating: "Basic",
            size: "39 MB"
        )
    ]
}
