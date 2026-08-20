import SwiftUI

/// Screen for choosing the on-device transcription model.
struct AIModelsView: View {
    @StateObject private var downloadService = ModelDownloadService.shared
    @AppStorage(ModelSelection.defaultsKey) private var selectedModel: String = ModelSelection.none
    @AppStorage("modelUseCase") private var useCaseRaw: String = AIModel.UseCase.dictation.rawValue

    /// Keeps the content from stretching edge-to-edge on a wide window, so the
    /// name and its action never sit at opposite ends of a huge empty band.
    private let maxContentWidth: CGFloat = 940

    // MARK: - Derived

    private var transcription: TranscriptionManager { TranscriptionManager.shared }
    private var capability: DeviceCapability { .current }
    private var useCase: AIModel.UseCase { AIModel.UseCase(rawValue: useCaseRaw) ?? .dictation }
    private var recommendedModel: AIModel { AIModel.recommendedModel(for: capability, useCase: useCase) }
    private var selectedModelObject: AIModel? {
        AIModel.availableModels.first { $0.variant == selectedModel }
    }

    private func isDownloaded(_ variant: String) -> Bool {
        downloadService.isDownloaded(variant)
    }

    /// Engine groups for the list — the recommended model is intentionally left
    /// out here because it already headlines the hero (no more duplication).
    private var engineGroups: [(title: String, subtitle: String, models: [AIModel])] {
        [
            (title: "Parakeet", subtitle: "NVIDIA · fastest, near-Whisper accuracy",
             models: AIModel.models(for: .parakeet)),
            (title: "Whisper", subtitle: "OpenAI · most accurate, a touch slower",
             models: AIModel.models(for: .whisper)),
        ]
        .map { ($0.title, $0.subtitle, $0.models.filter { $0.variant != recommendedModel.variant }) }
        .filter { !$0.2.isEmpty }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                currentStrip
                heroSection
                listSection
            }
            .frame(maxWidth: maxContentWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 32)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .background(Color.clear)
        .onAppear {
            // Refresh download status; never overwrite the persisted selection here (#79).
            Task { await downloadService.refreshDownloadedModels() }
        }
    }

    // MARK: - Current model strip

    /// Always-visible "what am I using right now", so the active model isn't
    /// buried at the bottom of the list.
    private var currentStrip: some View {
        let sel = selectedModelObject
        let differsFromPick = sel != nil && sel?.variant != recommendedModel.variant
        return HStack(spacing: 13) {
            ZStack {
                Circle().fill(Color.brandAccentSoft)
                Image(systemName: sel == nil ? "questionmark" : "waveform")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.brandAccent)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text("CURRENTLY USING")
                    .font(Typography.uiBold(10)).tracking(1.2)
                    .foregroundStyle(Color.textMuted)
                Text(sel?.name ?? "No model selected yet")
                    .font(Typography.uiBold(16))
                    .foregroundStyle(sel == nil ? Color.textMuted : Color.textPrimary)
            }

            Spacer(minLength: 8)

            if differsFromPick {
                Text("A better-matched pick is recommended below")
                    .font(Typography.uiMedium(12))
                    .foregroundStyle(Color.textMuted)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.border.opacity(0.6), lineWidth: 1)
        )
    }

    // MARK: - Hero

    private var heroSection: some View {
        let rec = recommendedModel
        let downloaded = isDownloaded(rec.variant)
        let active = selectedModel == rec.variant

        return HStack(alignment: .top, spacing: 32) {
            // LEFT — the pitch.
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles").font(.system(size: 11, weight: .bold))
                    Text("RECOMMENDED FOR YOU")
                        .font(Typography.uiBold(11)).tracking(1.4)
                }
                .foregroundStyle(Color.brandAccent)

                Text(rec.name)
                    .font(Typography.heroName)
                    .foregroundStyle(Color.textPrimary)
                    .padding(.top, 16)

                LanguageBadge(isEnglishOnly: rec.isEnglishOnly)
                    .padding(.top, 12)

                Text(AIModel.recommendationReason(for: rec, capability: capability, useCase: useCase))
                    .font(Typography.ui(15))
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)

                HStack(spacing: 7) {
                    Image(systemName: "laptopcomputer").font(.system(size: 12))
                    Text("Your Mac · \(capability.summary)")
                        .font(Typography.uiMedium(12))
                }
                .foregroundStyle(Color.textMuted)
                .padding(.top, 16)

                Spacer(minLength: 20)

                heroAction(rec: rec, downloaded: downloaded, active: active)
                    .padding(.top, 20)
            }

            // RIGHT — the performance panel, so the hero isn't half-empty.
            VStack(alignment: .leading, spacing: 14) {
                Text("HOW IT PERFORMS")
                    .font(Typography.uiBold(9)).tracking(1)
                    .foregroundStyle(Color.textMuted)
                MetricBarsStacked(model: rec)
                HStack(spacing: 7) {
                    Image(systemName: "internaldrive").font(.system(size: 11))
                    Text("\(rec.size) download").font(Typography.uiMedium(12))
                }
                .foregroundStyle(Color.textSecondary)
            }
            .padding(18)
            .frame(width: 300, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.textPrimary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.textPrimary.opacity(0.06), lineWidth: 1)
            )
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.bgCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.brandAccent.opacity(0.07), Color.brandAccent.opacity(0.0)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.brandAccent.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: Color.brandAccent.opacity(0.10), radius: 20, x: 0, y: 8)
    }

    /// The hero is the *only* place the recommended model can be downloaded from
    /// — it is deliberately filtered out of the list below — so it has to carry
    /// the full download state machine (progress, cancel, failure, retry). It
    /// previously showed a bare "Download" button in every state, so a download
    /// that was running (or had failed) looked like a button that did nothing.
    private func heroAction(rec: AIModel, downloaded: Bool, active: Bool) -> some View {
        let downloading = downloadService.isDownloading[rec.variant] ?? false
        let error = downloadService.downloadError[rec.variant]
        let warming = transcription.warmingVariant == rec.variant

        return VStack(alignment: .leading, spacing: 12) {
            if downloading {
                heroDownloadProgress(variant: rec.variant)
            } else if warming {
                // Checked before the "default model" branch: selecting flips
                // `active` immediately, so an equally-early `active` check would
                // hide the readiness spinner entirely.
                HStack(spacing: 9) {
                    Spinner(size: 13, lineWidth: 2, tint: Color.brandAccent)
                    Text("Getting it ready…")
                        .font(Typography.uiBold(13))
                        .foregroundStyle(Color.textSecondary)
                }
            } else if active && downloaded {
                HStack(spacing: 7) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("This is your default model").font(Typography.uiBold(13))
                }
                .foregroundStyle(Color.brandAccent)
            } else if downloaded {
                Button {
                    // Selecting used to only write the preference, leaving the
                    // model to load lazily at the first dictation — which is
                    // exactly the mid-sentence "warming up" wait. Load it here,
                    // while the user is still on this screen.
                    selectedModel = rec.variant
                    transcription.warmUp(variant: rec.variant)
                } label: {
                    ActionButton.label(title: "Use this model", icon: "arrow.right",
                                       style: .primary, large: true)
                }
                .buttonStyle(.plain)
            } else {
                if let error {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                        Text(error)
                            .font(Typography.ui(12))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(Color.accentError)
                    .frame(maxWidth: 420, alignment: .leading)
                }

                Button {
                    downloadService.downloadModel(variant: rec.variant)
                } label: {
                    ActionButton.label(title: error == nil ? "Download" : "Try again",
                                       icon: error == nil ? "arrow.down" : "arrow.clockwise",
                                       style: .primary, large: true)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Live progress for the hero's download, with a way out of it.
    private func heroDownloadProgress(variant: String) -> some View {
        let progress = downloadService.downloadProgress[variant] ?? 0.0
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                Spinner(size: 13, lineWidth: 2, tint: Color.brandAccent)
                Text("Downloading…")
                    .font(Typography.uiMedium(13))
                    .foregroundStyle(Color.textSecondary)
                Text("\(Int(progress * 100))%")
                    .font(Typography.uiBold(13))
                    .foregroundStyle(Color.brandAccent)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.textPrimary.opacity(0.08)).frame(height: 6)
                    Capsule().fill(Color.brandAccent)
                        .frame(width: max(6, geo.size.width * progress), height: 6)
                        .animation(.easeOut(duration: 0.2), value: progress)
                }
            }
            .frame(width: 320, height: 6)

            HStack(spacing: 12) {
                Button {
                    downloadService.cancelDownload(for: variant)
                } label: {
                    ActionButton.label(title: "Cancel", icon: "xmark", style: .secondary)
                }
                .buttonStyle(.plain)

                Text("Large models take a few minutes on a first download.")
                    .font(Typography.ui(11))
                    .foregroundStyle(Color.textMuted)
            }
        }
    }

    // MARK: - List

    private var listSection: some View {
        VStack(alignment: .leading, spacing: 26) {
            ForEach(engineGroups, id: \.title) { group in
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(group.title)
                            .font(Typography.sectionTitle)
                            .foregroundStyle(Color.textPrimary)
                        Text(group.subtitle)
                            .font(Typography.ui(12))
                            .foregroundStyle(Color.textMuted)
                    }

                    ForEach(group.models) { model in
                        ModelRow(
                            model: model,
                            selectedModel: $selectedModel,
                            isRecommended: false
                        )
                    }
                }
            }
        }
    }
}

#Preview {
    AIModelsView().frame(width: 900, height: 900).background(Color.bgApp)
}
