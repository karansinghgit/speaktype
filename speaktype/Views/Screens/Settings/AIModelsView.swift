import SwiftUI

/// Screen for managing AI transcription models
struct AIModelsView: View {
    // MARK: - Properties
    
    @StateObject private var downloadService = ModelDownloadService.shared
    @AppStorage("selectedModelVariant") private var selectedModel: String = "openai_whisper-base"
    @State private var models = AIModel.availableModels
    
    // MARK: - Computed Properties
    
    var selectedModelName: String {
        models.first(where: { $0.variant == selectedModel })?.name ?? "Unknown Model"
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                headerSection
                currentModelCard
                modelsListSection
            }
            .padding(30)
        }
        .background(Color.contentBackground)
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AI Models")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            Text("Manage your local transcription models powered by WhisperKit.")
                .font(.body)
                .foregroundStyle(.gray)
        }
    }
    
    private var currentModelCard: some View {
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
    
    private var modelsListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Available Models")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                Spacer()
            }
            
            VStack(spacing: 16) {
                ForEach($models) { $model in
                    ModelRow(model: $model, selectedModel: $selectedModel)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AIModelsView()
        .background(Color.black)
}
