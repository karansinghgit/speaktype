import SwiftUI

/// Reusable component for displaying a single AI model in the models list
struct ModelRow: View {
    @Binding var model: AIModel
    @Binding var selectedModel: String
    @ObservedObject var downloadService = ModelDownloadService.shared
    
    // MARK: - Computed Properties
    
    var progress: Double {
        downloadService.downloadProgress[model.variant] ?? 0.0
    }
    
    var isDownloading: Bool {
        downloadService.isDownloading[model.variant] ?? false
    }
    
    var isDownloaded: Bool {
        progress >= 1.0
    }
    
    var isActive: Bool {
        selectedModel == model.variant
    }
    
    var downloadError: String? {
        downloadService.downloadError[model.variant]
    }
    
    var ratingColor: Color {
        switch model.rating {
        case "Best", "Excellent": return .purple
        case "Great", "Good": return .green
        case "Standard": return .blue
        case "Basic": return .gray
        default: return .white
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        HStack {
            // Model Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(model.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    // Rating Badge
                    Text(model.rating)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ratingColor.opacity(0.2))
                        .foregroundStyle(ratingColor)
                        .clipShape(Capsule())
                    
                    if isActive {
                        Text("(Active)")
                            .font(.caption)
                            .foregroundStyle(Color.green)
                    }
                }
                
                HStack(spacing: 6) {
                    Text(model.details)
                        .font(.caption)
                        .foregroundStyle(.gray)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    
                    Text(model.size)
                        .font(.caption)
                        .foregroundStyle(.gray.opacity(0.8))
                }
            }
            
            Spacer()
            
            // Actions
            actionButton
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? Color.green.opacity(0.5) : Color.white.opacity(0.05), lineWidth: 1)
        )
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var actionButton: some View {
        if isDownloaded {
            downloadedActions
        } else if isDownloading {
            downloadingProgress
        } else {
            downloadButton
        }
    }
    
    private var downloadedActions: some View {
        HStack(spacing: 12) {
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
        }
    }
    
    private var downloadingProgress: some View {
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
    }
    
    private var downloadButton: some View {
        VStack(alignment: .trailing, spacing: 8) {
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
            
            Button(action: {
                Task {
                    let result = await downloadService.deleteModel(variant: model.variant)
                    await MainActor.run {
                        downloadService.downloadError[model.variant] = "Manual Delete: \(result)"
                    }
                }
            }) {
                Image(systemName: "trash")
                    .foregroundStyle(.gray)
                    .padding(6)
            }
            .buttonStyle(.plain)
            .help("Force Delete Cache")
            
            if let error = downloadError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 150)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ModelRow(
        model: .constant(AIModel.availableModels[0]),
        selectedModel: .constant("openai_whisper-base")
    )
    .padding()
    .background(Color.black)
}
