import SwiftUI

/// Screen for managing AI transcription models
struct AIModelsView: View {
    // MARK: - Properties
    
    @StateObject private var downloadService = ModelDownloadService.shared
    @AppStorage("selectedModelVariant") private var selectedModel: String = ""
    @State private var models = AIModel.availableModels
    
    // MARK: - Computed Properties
    
    var selectedModelName: String {
        models.first(where: { $0.variant == selectedModel })?.name ?? "No model downloaded yet"
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                currentModelCard
                modelsListSection
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .background(Color.clear)
        .onAppear {
            // Refresh model download status when view appears
            Task {
                await downloadService.refreshDownloadedModels()
                
                // Auto-fallback: If selected model isn't downloaded, switch to first available
                if !selectedModel.isEmpty {
                    let isSelectedModelDownloaded = downloadService.downloadProgress[selectedModel] ?? 0.0 >= 1.0
                    
                    if !isSelectedModelDownloaded {
                        // Find first downloaded model
                        if let firstDownloaded = downloadService.downloadProgress.first(where: { $0.value >= 1.0 })?.key {
                            print("⚠️ Selected model '\(selectedModel)' not found. Auto-switching to '\(firstDownloaded)'")
                            selectedModel = firstDownloaded
                        } else {
                            print("⚠️ No models downloaded. Please download a model to use the app.")
                            selectedModel = "" // Clear invalid selection
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("AI Models")
                .font(Typography.displayLarge)
                .foregroundStyle(Color.textPrimary)
            
            Text("Manage your local transcription models powered by WhisperKit.")
                .font(Typography.bodySmall)
                .foregroundStyle(Color.textSecondary)
        }
    }
    
    private var currentModelCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Default Model")
                .font(Typography.captionSmall)
                .foregroundStyle(Color.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)
            
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
                .stroke(Color.border.opacity(0.5), lineWidth: 1)
        )
        .cardShadow()
    }
    
    private var modelsListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Available Models")
                .font(Typography.headlineLarge)
                .foregroundStyle(Color.textPrimary)
            
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
