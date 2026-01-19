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
        default: return Color.textPrimary
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                // Model Info
                VStack(alignment: .leading, spacing: 8) {
                    // Model Name
                    Text(model.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.textPrimary)
                    
                    // Model Details - Icons and stats
                    HStack(spacing: 12) {
                        // Multilingual icon
                        HStack(spacing: 4) {
                            Image(systemName: "globe")
                                .font(.caption)
                            Text("Multilingual")
                                .font(.caption)
                        }
                        .foregroundStyle(.gray)
                        
                        // Size icon
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle")
                                .font(.caption)
                            Text(model.size)
                                .font(.caption)
                        }
                        .foregroundStyle(.gray)
                        
                        // Speed rating (showing dots)
                        HStack(spacing: 4) {
                            Text("Speed")
                                .font(.caption)
                            HStack(spacing: 2) {
                                ForEach(0..<3) { i in
                                    Circle()
                                        .fill(i < Int(model.speed / 3.3) ? Color.yellow : Color.gray.opacity(0.3))
                                        .frame(width: 4, height: 4)
                                }
                            }
                            Text(String(format: "%.1f", model.speed))
                                .font(.caption)
                        }
                        .foregroundStyle(.gray)
                        
                        // Accuracy rating
                        HStack(spacing: 4) {
                            Text("Accuracy")
                                .font(.caption)
                            HStack(spacing: 2) {
                                ForEach(0..<3) { i in
                                    Circle()
                                        .fill(i < Int(model.accuracy / 3.3) ? Color.green : Color.gray.opacity(0.3))
                                        .frame(width: 4, height: 4)
                                }
                            }
                            Text(String(format: "%.1f", model.accuracy))
                                .font(.caption)
                        }
                        .foregroundStyle(.gray)
                    }
                    
                    // Description
                    Text(model.details)
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .padding(.top, 4)
                }
                
                Spacer()
                
                // Action button (top right)
                actionButton
            }
            .padding()
            
            // Download progress section (only shown when downloading)
            if isDownloading {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Downloading \(model.variant) Model")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                        
                        Spacer()
                        
                        Text("\(Int(progress * 100))%")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                    }
                    
                    // Blue progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background track
                            Rectangle()
                                .fill(Color.bgHover)
                                .frame(height: 4)
                            
                            // Progress fill
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: geometry.size.width * progress, height: 4)
                        }
                    }
                    .frame(height: 4)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .background(Color.bgCard)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? Color.green.opacity(0.5) : Color.borderCard, lineWidth: 1)
        )
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var actionButton: some View {
        if isDownloaded {
            downloadedActions
        } else if isDownloading {
            downloadingButton
        } else {
            downloadButton
        }
    }
    
    private var downloadedActions: some View {
        HStack(spacing: 12) {
            if isActive {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                    Text("Selected")
                        .font(.subheadline)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.2))
                .foregroundStyle(Color.green)
                .cornerRadius(20)
            } else {
                Button("Use") {
                    selectedModel = model.variant
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.bgHover)
                .foregroundStyle(Color.textPrimary)
                .cornerRadius(20)
                .buttonStyle(.plain)
            }
            
            // Delete button (Only available when downloaded)
            Button(action: {
                Task {
                    _ = await downloadService.deleteModel(variant: model.variant)
                }
            }) {
                Image(systemName: "trash")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .padding(8)
            }
            .buttonStyle(.plain)
            .help("Delete Model")
        }
    }
    
    private var downloadingButton: some View {
        HStack(spacing: 6) {
            Text("Downloading...")
                .font(.subheadline)
                .fontWeight(.medium)
            Image(systemName: "info.circle")
                .font(.subheadline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.blue)
        .foregroundStyle(.white)
        .cornerRadius(20)
    }
    
    private var downloadButton: some View {
        Button(action: {
            downloadService.downloadModel(variant: model.variant)
        }) {
            HStack(spacing: 6) {
                Text("Download")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Image(systemName: "arrow.down.circle")
                    .font(.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.blue)
            .foregroundStyle(.white)
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        // Normal state
        ModelRow(
            model: .constant(AIModel.availableModels[0]),
            selectedModel: .constant("openai_whisper-base")
        )
        
        // Downloading state (simulated)
        ModelRow(
            model: .constant(AIModel.availableModels[0]),
            selectedModel: .constant("openai_whisper-base")
        )
        .onAppear {
            ModelDownloadService.shared.isDownloading["openai_whisper-large-v3_turbo"] = true
            ModelDownloadService.shared.downloadProgress["openai_whisper-large-v3_turbo"] = 0.04
        }
    }
    .padding()
    .background(Color.black)
}
