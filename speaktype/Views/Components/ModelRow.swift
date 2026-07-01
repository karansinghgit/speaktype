import SwiftUI

/// Reusable component for displaying a single AI model in the models list
struct ModelRow: View {
    @Binding var model: AIModel
    @Binding var selectedModel: String
    @ObservedObject var downloadService = ModelDownloadService.shared

    // Route model loading/state through the unified transcription manager
    private var transcription: TranscriptionManager { TranscriptionManager.shared }

    // State for model loading
    @State private var isLoadingModel = false
    @State private var loadError: String?
    @State private var loadingStartTime: Date?
    @State private var loadingElapsed: TimeInterval = 0
    @State private var loadingTimer: Timer?

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

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                // Model Info
                VStack(alignment: .leading, spacing: 10) {
                    // Model Name
                    Text(model.name)
                        .font(Typography.cardTitle)
                        .foregroundStyle(Color.textPrimary)

                    // Model Details - Icons and stats
                    HStack(spacing: 14) {
                        ModelMetaItem(
                            icon: model.isEnglishOnly ? "character.book.closed" : "globe",
                            text: model.languageSupportLabel
                        )
                        ModelMetaItem(icon: "arrow.down.circle", text: model.size)

                        // Speed rating
                        HStack(spacing: 4) {
                            Text("Speed")
                                .font(Typography.cardMeta)
                            RatingDots(value: model.speed, maxValue: 10, color: .orange)
                            Text(String(format: "%.1f", model.speed))
                                .font(Typography.cardMetaBold)
                        }
                        .foregroundStyle(Color.textMuted)

                        // Accuracy rating
                        HStack(spacing: 4) {
                            Text("Accuracy")
                                .font(Typography.cardMeta)
                            RatingDots(value: model.accuracy, maxValue: 10, color: .green)
                            Text(String(format: "%.1f", model.accuracy))
                                .font(Typography.cardMetaBold)
                        }
                        .foregroundStyle(Color.textMuted)
                    }

                    // Description
                    Text(model.details)
                        .font(Typography.cardDescription)
                        .foregroundStyle(Color.textSecondary)

                    // RAM warning for undersized devices
                    if let warning = model.ramWarning(deviceRAMGB: WhisperService.deviceRAMGB) {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                            Text(warning)
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(Color.orange)
                    }

                    // Load error display
                    if let loadError = loadError {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                            Text(loadError)
                                .font(.system(size: 11))
                                .lineLimit(2)
                        }
                        .foregroundStyle(Color.red)
                    }
                }

                Spacer()

                // Action button
                actionButton
            }
            .padding(18)

            // Download progress
            if isDownloading {
                downloadProgressSection
            }
        }
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isActive ? Color.textPrimary.opacity(0.3) : Color.border.opacity(0.5),
                    lineWidth: 1)
        )
        .cardShadow()
    }

    // MARK: - Subviews

    private var downloadProgressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Downloading \(model.variant)")
                    .font(Typography.cardMeta)
                    .foregroundStyle(Color.textSecondary)

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(Typography.cardMetaBold)
                    .foregroundStyle(Color.textSecondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.bgHover)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.textSecondary.opacity(0.4))
                        .frame(width: geometry.size.width * progress, height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
    }

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
        HStack(spacing: 10) {
            if isActive {
                // Show warning if selected model isn't actually downloaded
                if !isDownloaded {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                        Text("Missing")
                            .font(Typography.buttonLabelSmall)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.2))
                    .foregroundStyle(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .help(
                        "This model is selected but not downloaded. Download it or select another model."
                    )
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                        Text("Selected")
                            .font(Typography.buttonLabelSmall)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.black)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            } else {
                if isLoadingModel {
                    // Show loading state with descriptive stage text
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 12, height: 12)
                            Text(
                                transcription.loadingStage.isEmpty
                                    ? "Loading..." : transcription.loadingStage
                            )
                            .font(Typography.buttonLabelSmall)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(white: 0.95))
                        .foregroundStyle(Color.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        if loadingElapsed > 15 {
                            Text(
                                loadingElapsed > 30
                                    ? "Taking longer than expected…" : "\(Int(loadingElapsed))s"
                            )
                            .font(.system(size: 10))
                            .foregroundStyle(loadingElapsed > 30 ? Color.orange : Color.textMuted)
                        }
                    }
                    .help("First load may take 10-30 seconds")
                } else {
                    // Downloaded but not selected - show "Use" button
                    Button {
                        loadAndSelectModel()
                    } label: {
                        Text("Use")
                            .font(Typography.buttonLabelSmall)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .foregroundStyle(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help("Set as default model")
                }
            }

            Button(action: {
                Task {
                    _ = await downloadService.deleteModel(variant: model.variant)
                    // If the model we just removed was the active selection, clear it
                    // so nothing tries to load a model that's no longer on disk.
                    if selectedModel == model.variant {
                        selectedModel = ModelSelection.none
                    }
                }
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textMuted)
                    .padding(8)
            }
            .buttonStyle(.plain)
            .help("Delete Model")
        }
    }

    private var downloadingButton: some View {
        Button(action: {
            downloadService.cancelDownload(for: model.variant)
        }) {
            HStack(spacing: 6) {
                Text("Cancel")
                    .font(Typography.buttonLabelSmall)
                Image(systemName: "xmark.circle")
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(white: 0.9))
            .foregroundStyle(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var downloadButton: some View {
        Button(action: {
            downloadService.downloadModel(variant: model.variant)
        }) {
            HStack(spacing: 6) {
                Text("Download")
                    .font(Typography.buttonLabel)
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Color.white)
            .foregroundStyle(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Model Loading

    /// Load the model into memory before selecting it
    private func loadAndSelectModel() {
        isLoadingModel = true
        loadError = nil
        loadingStartTime = Date()
        loadingElapsed = 0

        // Start a timer to track elapsed time
        loadingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let start = loadingStartTime {
                loadingElapsed = Date().timeIntervalSince(start)
            }
        }

        Task {
            do {
                print("🔄 Loading model into shared service: \(model.variant)")

                // Load into the SHARED WhisperService so MiniRecorderView can use it
                try await transcription.loadModel(variant: model.variant)

                print("✅ Model loaded successfully: \(model.variant)")

                await MainActor.run {
                    stopLoadingTimer()
                    isLoadingModel = false
                    selectedModel = model.variant
                }
            } catch {
                print("❌ Failed to load model \(model.variant): \(error.localizedDescription)")

                await MainActor.run {
                    stopLoadingTimer()
                    isLoadingModel = false
                    loadError = error.localizedDescription
                }
            }
        }
    }

    private func stopLoadingTimer() {
        loadingTimer?.invalidate()
        loadingTimer = nil
        loadingStartTime = nil
        loadingElapsed = 0
    }
}

// MARK: - Supporting Components

private struct ModelMetaItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
            Text(text)
                .font(Typography.cardMeta)
        }
        .foregroundStyle(Color.textMuted)
    }
}

private struct RatingDots: View {
    let value: Double
    let maxValue: Double
    let color: Color

    private var filledDots: Int {
        Int((value / maxValue) * 3)
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(i < filledDots ? color : Color.textMuted.opacity(0.3))
                    .frame(width: 5, height: 5)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        ModelRow(
            model: .constant(AIModel.availableModels[0]),
            selectedModel: .constant("openai_whisper-base")
        )
    }
    .padding()
    .background(Color.bgApp)
}
