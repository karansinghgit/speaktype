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
        .background(Color.clear)
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AI Models")
                .font(Typography.displayLarge)
                .foregroundStyle(Color.textPrimary)
            
            Text("Manage your local transcription models powered by WhisperKit.")
                .font(Typography.cardDescription)
                .foregroundStyle(Color.textSecondary)
        }
    }
    
    private var currentModelCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Default Model")
                .font(Typography.labelMedium)
                .foregroundStyle(Color.textSecondary)
            
            Text(selectedModelName)
                .font(Typography.headlineMedium)
                .foregroundStyle(Color.textPrimary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.border, lineWidth: 1)
        )
        .cardShadow()
    }
    
    private var modelsListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Available Models")
                    .font(Typography.displaySmall)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
            }
            
            VStack(spacing: 12) {
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
