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
    
    private var hasAnyModelDownloaded: Bool {
        downloadService.downloadProgress.values.contains { $0 >= 1.0 }
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                
                // Show setup banner if no model downloaded
                if !hasAnyModelDownloaded {
                    setupBanner
                }
                
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
            
            HStack(spacing: 6) {
                Text("Manage your local transcription models powered by WhisperKit.")
                    .font(Typography.bodySmall)
                    .foregroundStyle(Color.textSecondary)
                
                // Info icon with tooltip on hover
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textMuted)
                    .help("First transcription after selecting a model may take 10-30 seconds while the AI loads.")
            }
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
    
    private var setupBanner: some View {
        HStack(spacing: 16) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(Color.textPrimary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Download a Model to Get Started")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                
                Text("Choose a model below to enable voice transcription. We recommend Whisper Base for most users.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
            }
            
            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.textPrimary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.textPrimary.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    AIModelsView()
        .background(Color.black)
}
