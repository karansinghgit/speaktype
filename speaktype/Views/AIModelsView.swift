import SwiftUI

struct AIModelsView: View {
    @StateObject private var downloadService = ModelDownloadService.shared
    @AppStorage("selectedModelVariant") private var selectedModel: String = "openai_whisper-base"
    
    // Using standard WhisperKit model variants
    @State private var models = [
        AIModel(
            name: "Whisper Base",
            variant: "openai_whisper-base",
            details: "English-only • Optimized for Apple Silicon"
        ),
        AIModel(
            name: "Whisper Small",
            variant: "openai_whisper-small",
            details: "English-only • Higher accuracy"
        ),
        AIModel(
            name: "Whisper Tiny",
            variant: "openai_whisper-tiny",
            details: "Multilingual • Fastest"
        )
    ]
    
    // Helper to get name of selected model
    var selectedModelName: String {
        models.first(where: { $0.variant == selectedModel })?.name ?? "Unknown Model"
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                // Header (Redesigned)
                VStack(alignment: .leading, spacing: 10) {
                    Text("AI Models")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    Text("Manage your local transcription models powered by WhisperKit.")
                        .font(.body)
                        .foregroundStyle(.gray)
                }
                
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Default Model")
                            .font(.headline)
                            .foregroundStyle(.gray)
                        Text(selectedModelName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.contentBackground.opacity(0.5))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                
                HStack {
                   Text("Available Models")
                       .font(.title2)
                       .fontWeight(.bold)
                       .foregroundStyle(.white)
                   Spacer()
                }
                
                // Models List
                VStack(spacing: 16) {
                    ForEach($models) { $model in
                        ModelRow(model: $model, selectedModel: $selectedModel)
                    }
                }
            }
            .padding(30)
        }
        .background(Color.contentBackground)
    }
}

struct AIModel: Identifiable {
    let id = UUID()
    let name: String
    let variant: String
    let details: String
    // status is derived from service now
}

struct ModelRow: View {
    @Binding var model: AIModel
    @Binding var selectedModel: String // Bind to parent selection
    @ObservedObject var downloadService = ModelDownloadService.shared
    
    var progress: Double {
        downloadService.downloadProgress[model.variant] ?? 0.0
    }
    
    var isDownloading: Bool {
        downloadService.isDownloading[model.variant] ?? false
    }
    
    var isDownloaded: Bool {
        // Placeholder check. In real app, check file existence or WhisperKit.isModelAvailable(variant)
        return progress >= 1.0
    }
    
    var isActive: Bool {
        selectedModel == model.variant
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(model.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                    if isActive {
                        Text("(Active)")
                            .font(.caption)
                            .foregroundStyle(Color.green)
                    }
                }
                Text(model.details)
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            
            Spacer()
            
            if isDownloaded {
                 // If downloaded, allow selection
                 if isActive {
                     HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Selected")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .foregroundStyle(Color.green)
                 } else {
                     Button("Use") {
                         selectedModel = model.variant
                     }
                     .padding(.horizontal, 12)
                     .padding(.vertical, 6)
                     .background(Color.white.opacity(0.1))
                     .foregroundStyle(.white)
                     .cornerRadius(16)
                     .buttonStyle(.plain)
                 }
            } else if isDownloading {
                HStack {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .frame(width: 80)
                        .tint(Color.appRed)
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .frame(width: 35, alignment: .trailing)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.2))
                .cornerRadius(16)
            } else {
                Button(action: {
                    downloadService.downloadModel(variant: model.variant)
                }) {
                    HStack(spacing: 4) {
                        Text("Download")
                        Image(systemName: "arrow.down.circle")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.appRed)
                    .foregroundStyle(.white)
                    .cornerRadius(16)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? Color.green.opacity(0.5) : Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}
