import SwiftUI

/// A single AI-model card. Clean two-font layout (Clash Display for the name,
/// Satoshi for everything else) with a single warm terracotta accent.
struct ModelRow: View {
    let model: AIModel
    @Binding var selectedModel: String
    /// Highlights this card as the engine's recommendation for this Mac.
    var isRecommended: Bool = false

    @ObservedObject var downloadService = ModelDownloadService.shared
    private var transcription: TranscriptionManager { TranscriptionManager.shared }

    @State private var isLoadingModel = false
    @State private var loadError: String?
    @State private var loadingStartTime: Date?
    @State private var loadingElapsed: TimeInterval = 0
    @State private var loadingTimer: Timer?
    @State private var isHovered = false
    @State private var appeared = false
    @State private var showDeleteConfirmation = false

    // MARK: - Derived state

    var progress: Double { downloadService.downloadProgress[model.variant] ?? 0.0 }
    var isDownloading: Bool { downloadService.isDownloading[model.variant] ?? false }
    var isDownloaded: Bool { progress >= 1.0 }
    var isActive: Bool { selectedModel == model.variant }
    var downloadError: String? { downloadService.downloadError[model.variant] }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 11) {
                    titleRow
                    Text(model.details)
                        .font(Typography.ui(13))
                        .foregroundStyle(Color.textSecondary)
                    metaRow
                    MetricBars(model: model, appeared: appeared)

                    if let warning = model.ramWarning(deviceRAMGB: WhisperService.deviceRAMGB) {
                        note(icon: "exclamationmark.triangle.fill", text: warning, tint: .accentWarning)
                    }
                    if let loadError {
                        note(icon: "xmark.circle.fill", text: loadError, tint: .accentError)
                    }
                    if let downloadError {
                        note(icon: "xmark.circle.fill", text: downloadError, tint: .accentError)
                    }
                }

                Spacer(minLength: 8)

                actionColumn
            }
            .padding(20)

            if isDownloading { downloadProgressSection }
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isActive ? Color.brandAccentSoft : Color.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    isActive ? Color.brandAccent.opacity(0.4)
                        : Color.border.opacity(isHovered ? 1.0 : 0.5),
                    lineWidth: isActive ? 1.5 : 1
                )
        )
        .shadow(color: .black.opacity(isHovered ? 0.09 : 0.03),
                radius: isHovered ? 14 : 6, x: 0, y: isHovered ? 6 : 2)
        .animation(.easeOut(duration: 0.16), value: isHovered)
        .animation(.easeOut(duration: 0.16), value: isActive)
        .onHover { isHovered = $0 }
        .onAppear { withAnimation(.easeOut(duration: 0.5).delay(0.05)) { appeared = true } }
        .alert("Delete \(model.name)?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { deleteModel() }
        } message: {
            Text("This removes the downloaded model files. You can download the model again later.")
        }
    }

    // MARK: - Header

    private var titleRow: some View {
        HStack(spacing: 9) {
            Text(model.name)
                .font(Typography.modelName)
                .foregroundStyle(Color.textPrimary)

            LanguageBadge(isEnglishOnly: model.isEnglishOnly)

            if isActive && isDownloaded {
                statusBadge(text: "Selected", icon: "checkmark", tint: Color.brandAccent)
            } else if isDownloaded {
                statusBadge(text: "Installed", icon: "arrow.down.circle.fill",
                            tint: Color.textMuted)
            }
        }
    }

    private func statusBadge(text: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 9, weight: .bold))
            Text(text).font(Typography.uiBold(10)).textCase(.uppercase).tracking(0.5)
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Capsule().fill(tint.opacity(0.14)))
        .foregroundStyle(tint)
    }

    private var metaRow: some View {
        HStack(spacing: 8) {
            chip(icon: "internaldrive", text: model.size)
        }
    }

    private func chip(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 10))
            Text(text).font(Typography.uiMedium(12))
        }
        .foregroundStyle(Color.textSecondary)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(Capsule().fill(Color.textPrimary.opacity(0.05)))
    }

    private func note(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 10))
            Text(text).font(Typography.ui(11)).lineLimit(3)
        }
        .foregroundStyle(tint)
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionColumn: some View {
        HStack(spacing: 8) {
            if isDownloaded {
                if isActive {
                    // Already the default — no redundant button, the badge says it.
                    EmptyView()
                } else if isLoadingModel {
                    loadingIndicator
                } else {
                    Button(action: loadAndSelectModel) {
                        ActionButton.label(title: "Use", icon: "arrow.right", style: .secondary)
                    }
                    .buttonStyle(.plain).help("Set as default model")
                }
                Button(action: { showDeleteConfirmation = true }) {
                    Image(systemName: "trash").font(.system(size: 13))
                        .foregroundStyle(Color.textMuted).padding(8)
                        .background(Circle().fill(Color.textPrimary.opacity(isHovered ? 0.06 : 0)))
                }
                .buttonStyle(.plain).help("Delete model")
            } else if isDownloading {
                Button(action: { downloadService.cancelDownload(for: model.variant) }) {
                    ActionButton.label(title: "Cancel", icon: "xmark", style: .secondary)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: { downloadService.downloadModel(variant: model.variant) }) {
                    ActionButton.label(title: "Download", icon: "arrow.down", style: .primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var loadingIndicator: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 9) {
                Spinner(size: 13, lineWidth: 2, tint: Color.textSecondary)
                Text(transcription.loadingStage.isEmpty ? "Loading…" : transcription.loadingStage)
                    .font(Typography.uiMedium(12))
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.leading, 12).padding(.trailing, 15).padding(.vertical, 8)
            .background(Capsule().fill(Color.textPrimary.opacity(0.08)))
            .foregroundStyle(Color.textSecondary)

            if loadingElapsed > 15 {
                Text(loadingElapsed > 30 ? "Taking longer than expected…" : "\(Int(loadingElapsed))s")
                    .font(Typography.ui(10))
                    .foregroundStyle(loadingElapsed > 30 ? Color.accentWarning : Color.textMuted)
            }
        }
        .help("First load may take 10-30 seconds")
    }

    private var downloadProgressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Downloading…").font(Typography.uiMedium(12)).foregroundStyle(Color.textSecondary)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(Typography.uiBold(11))
                    .foregroundStyle(Color.brandAccent)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.textPrimary.opacity(0.08)).frame(height: 6)
                    Capsule().fill(Color.brandAccent).frame(width: max(6, geo.size.width * progress), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 20).padding(.bottom, 20)
    }

    // MARK: - Logic

    private func deleteModel() {
        Task {
            _ = await downloadService.deleteModel(variant: model.variant)
            await transcription.unloadModelIfCurrent(variant: model.variant)
            await MainActor.run {
                if selectedModel == model.variant { selectedModel = ModelSelection.none }
            }
        }
    }

    private func loadAndSelectModel() {
        isLoadingModel = true
        loadError = nil
        loadingStartTime = Date()
        loadingElapsed = 0
        loadingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let start = loadingStartTime { loadingElapsed = Date().timeIntervalSince(start) }
        }
        Task {
            do {
                try await transcription.loadModel(variant: model.variant)
                await MainActor.run {
                    stopLoadingTimer(); isLoadingModel = false; selectedModel = model.variant
                }
            } catch {
                await MainActor.run {
                    stopLoadingTimer(); isLoadingModel = false
                    loadError = error.localizedDescription
                }
            }
        }
    }

    private func stopLoadingTimer() {
        loadingTimer?.invalidate(); loadingTimer = nil
        loadingStartTime = nil; loadingElapsed = 0
    }
}

// MARK: - Language differentiator badge

/// The single most decision-relevant trait at a glance: multilingual vs English.
struct LanguageBadge: View {
    let isEnglishOnly: Bool

    var body: some View {
        let tint = isEnglishOnly ? Color.textMuted : Color.brandAccent
        Text(isEnglishOnly ? "ENGLISH" : "MULTILINGUAL")
            .font(Typography.uiBold(9)).tracking(0.6)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.14)))
            .foregroundStyle(tint)
    }
}

// MARK: - Shared metric bars

/// A single calm, continuous metric bar with a qualitative tier word.
/// No false-precision decimals, no gamified LED pips.
struct MetricBar: View {
    let label: String
    let tier: String
    let value: Double
    let tint: Color
    var appeared: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(label.uppercased())
                    .font(Typography.uiBold(9)).tracking(0.8)
                    .foregroundStyle(Color.textMuted)
                Text(tier)
                    .font(Typography.uiBold(11))
                    .foregroundStyle(tint)
                Spacer(minLength: 0)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.textPrimary.opacity(0.07)).frame(height: 6)
                    Capsule()
                        .fill(tint.opacity(0.7))
                        .frame(width: geo.size.width * (appeared ? value / 10.0 : 0), height: 6)
                        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: appeared)
                }
            }
            .frame(height: 6)
        }
    }
}

/// Speed + accuracy side by side — the card layout.
struct MetricBars: View {
    let model: AIModel
    var appeared: Bool = true

    var body: some View {
        HStack(spacing: 22) {
            MetricBar(label: "Speed", tier: model.speedTier, value: model.speed,
                      tint: .brandAccent, appeared: appeared).frame(width: 148)
            MetricBar(label: "Accuracy", tier: model.accuracyTier, value: model.accuracy,
                      tint: .brandAccent, appeared: appeared).frame(width: 148)
        }
        .padding(.top, 2)
    }
}

/// Speed + accuracy stacked — the hero's right column.
struct MetricBarsStacked: View {
    let model: AIModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MetricBar(label: "Speed", tier: model.speedTier, value: model.speed, tint: .brandAccent)
            MetricBar(label: "Accuracy", tier: model.accuracyTier, value: model.accuracy, tint: .brandAccent)
        }
    }
}

// MARK: - Shared action button label

/// One consistent button treatment used by both the hero and the cards, so the
/// same action never looks like three different buttons.
enum ActionButton {
    enum Style { case primary, secondary }

    static func label(title: String, icon: String?, style: Style, large: Bool = false) -> some View {
        HStack(spacing: 7) {
            Text(title).font(Typography.uiBold(large ? 14 : 13))
            if let icon { Image(systemName: icon).font(.system(size: large ? 12 : 11, weight: .bold)) }
        }
        .padding(.horizontal, large ? 22 : 16)
        .padding(.vertical, large ? 12 : 9)
        .background(
            Capsule().fill(style == .primary ? Color.accentPrimary : Color.textPrimary.opacity(0.06))
        )
        .foregroundStyle(style == .primary ? Color.bgApp : Color.textPrimary)
    }
}

#Preview {
    VStack(spacing: 16) {
        ModelRow(model: AIModel.availableModels[6], selectedModel: .constant("x"), isRecommended: true)
        ModelRow(model: AIModel.availableModels[0], selectedModel: .constant("x"))
    }
    .padding()
    .frame(width: 640)
    .background(Color.bgApp)
}
