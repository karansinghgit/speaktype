import AVFoundation
import Combine
import CoreMedia
import SwiftUI

struct MiniRecorderView: View {
    @ObservedObject private var audioRecorder = AudioRecordingService.shared
    private var transcription: TranscriptionManager { TranscriptionManager.shared }
    @State private var isListening = false

    @State private var isProcessing = false
    @State private var statusMessage = "Transcribing..."
    @State private var isWarmingUp = false
    /// When the current warm-up began, so the pill can show elapsed seconds
    /// instead of an open-ended spinner.
    @State private var warmUpStart: Date?
    @State private var warmUpElapsed: TimeInterval = 0
    @State private var warmUpTimer: Timer?
    @State private var showAccessibilityWarning = false
    var onCommit: ((String) -> Void)?
    var onCancel: (() -> Void)?

    @AppStorage(ModelSelection.defaultsKey) private var selectedModel: String = ModelSelection.none
    @AppStorage("recordingMode") private var recordingMode: Int = 0
    /// Whether we've already shown the one-time accessibility warning (release only).
    @AppStorage("hasShownAccessibilityWarning") private var hasShownAccessibilityWarning = false
    @AppStorage("transcriptionLanguage") private var transcriptionLanguage: String = "auto"
    @AppStorage("recentTranscriptionLanguages") private var recentLanguagesString: String = ""
    private let quickLanguageDefaults = ["en", "es", "fr", "de", "hi", "pt", "ja", "zh"]

    private var recentLanguageCodes: [String] {
        recentLanguagesString.split(separator: ",").map(String.init).filter { !$0.isEmpty }
    }

    private var quickLanguageCodes: [String] {
        var orderedCodes: [String] = []
        let candidateCodes = [transcriptionLanguage] + recentLanguageCodes + quickLanguageDefaults

        for code in candidateCodes where code != "auto" {
            guard !orderedCodes.contains(code) else { continue }
            guard GeneralSettingsTab.whisperLanguages.contains(where: { $0.code == code }) else {
                continue
            }
            orderedCodes.append(code)
        }

        return Array(orderedCodes.prefix(6))
    }

    private func updateRecentLanguages(code: String) {
        guard code != "auto" else { return }
        var recents = recentLanguageCodes.filter { $0 != code }
        recents.insert(code, at: 0)
        recentLanguagesString = recents.prefix(5).joined(separator: ",")
    }

    private func setLanguage(_ code: String) {
        transcriptionLanguage = code
        updateRecentLanguages(code: code)
    }

    private var currentLanguageLabel: String {
        if transcriptionLanguage == "auto" { return "Auto" }
        return spokenLanguageDisplayName(for: transcriptionLanguage)
    }

    private var spokenLanguageHelpText: String {
        if transcriptionLanguage == "auto" {
            return "Spoken language hint: Auto-detect. SpeakType will try to detect the language you are speaking."
        }

        return
            "Spoken language hint: \(spokenLanguageDisplayName(for: transcriptionLanguage)). If this does not match the language you actually speak, the result may be inaccurate or come back in the wrong language."
    }

    private var currentInputDeviceName: String {
        guard
            let selectedDeviceId = audioRecorder.selectedDeviceId,
            let device = audioRecorder.availableDevices.first(where: { $0.uniqueID == selectedDeviceId })
        else {
            return "No input selected"
        }

        return device.localizedName
    }

    private var inputDeviceHelpText: String {
        "Input device: \(currentInputDeviceName). Change microphones without going back to Settings."
    }

    private var isAccessibilityEnabled: Bool {
        AXIsProcessTrusted()
    }

    // MARK: - State for Escape key cancellation
    @State private var cancelCommit = false
    @State private var globalEscapeMonitor: Any?
    @State private var localEscapeMonitor: Any?

    @Environment(\.colorScheme) private var colorScheme
    // The pill window follows the system appearance, which can disagree with the
    // in-app theme override — so resolve "dark" from the app theme first.
    @AppStorage("appTheme") private var appTheme: AppTheme = .system

    /// Whether the glass pill should use its dark treatment.
    private var pillIsDark: Bool {
        switch appTheme {
        case .dark: return true
        case .light: return false
        case .system: return colorScheme == .dark
        }
    }

    // MARK: - State for Animation
    @State private var phase: CGFloat = 0

    /// Whether the pill is hovered — reveals the mic/mode/language controls inline.
    @State private var expanded = false

    /// Local recording start, set the moment we begin listening so the elapsed
    /// timer ticks reliably (independent of the service's non-published state).
    @State private var recordingStart: Date?

    /// Drives the soft pulse on the recording indicator dot.
    @State private var dotPulse = false

    // MARK: - Recorder helpers

    /// Compact language label for the always-visible tag ("Auto" or "EN").
    private var currentLanguageShort: String {
        transcriptionLanguage == "auto" ? "Auto" : transcriptionLanguage.uppercased()
    }

    /// First word of the selected input device, for a compact chip ("MacBook").
    private var shortDeviceName: String {
        let name = currentInputDeviceName
        return name.split(separator: " ").first.map(String.init) ?? name
    }

    private func elapsedString(_ now: Date) -> String {
        guard let start = recordingStart ?? audioRecorder.recordingStartTime else { return "0:00" }
        let s = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    /// Shared chip styling for the recorder's labeled controls (icon + word + chevron).
    private func recorderChipLabel(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold))
            Text(text).font(.system(size: 11, weight: .semibold))
            DoubleChevronIcon(color: .white.opacity(0.45))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.white.opacity(0.12)))
    }

    private var languageControl: some View {
        Menu {
            Button("Auto-detect") { setLanguage("auto") }
            if !quickLanguageCodes.isEmpty {
                Divider()
                ForEach(quickLanguageCodes, id: \.self) { code in
                    if let lang = GeneralSettingsTab.whisperLanguages.first(where: { $0.code == code }) {
                        Button(lang.name) { setLanguage(code) }
                    }
                }
            }
            Divider()
            Menu("More languages") {
                ForEach(GeneralSettingsTab.whisperLanguages, id: \.code) { lang in
                    Button(lang.name) { setLanguage(lang.code) }
                }
            }
            if !recentLanguageCodes.isEmpty {
                Divider()
                Button("Clear recents") { recentLanguagesString = "" }
            }
        } label: {
            recorderChipLabel(icon: "globe", text: currentLanguageShort)
        }
        .menuIndicator(.hidden)
        .menuStyle(.borderlessButton)
        .tint(.white.opacity(0.9))
        .fixedSize()
        .help(spokenLanguageHelpText)
    }

    private var micControl: some View {
        Menu {
            if audioRecorder.availableDevices.isEmpty {
                Button("No input devices found") {}.disabled(true)
            } else {
                ForEach(audioRecorder.availableDevices, id: \.uniqueID) { device in
                    Button {
                        selectAudioDevice(device.uniqueID)
                    } label: {
                        if audioRecorder.selectedDeviceId == device.uniqueID {
                            Label(device.localizedName, systemImage: "checkmark")
                        } else {
                            Text(device.localizedName)
                        }
                    }
                }
            }
            Divider()
            Button("Refresh inputs") { audioRecorder.fetchAvailableDevices() }
        } label: {
            recorderChipLabel(icon: "mic.fill", text: shortDeviceName)
        }
        .menuIndicator(.hidden)
        .menuStyle(.borderlessButton)
        .tint(.white.opacity(0.9))
        .fixedSize()
        .help(inputDeviceHelpText)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    private var modeControl: some View {
        Menu {
            Button {
                recordingMode = 0
            } label: {
                if recordingMode == 0 {
                    Label("Hold to talk", systemImage: "checkmark")
                } else {
                    Text("Hold to talk")
                }
            }
            Button {
                recordingMode = 1
            } label: {
                if recordingMode == 1 {
                    Label("Toggle on / off", systemImage: "checkmark")
                } else {
                    Text("Toggle on / off")
                }
            }
        } label: {
            recorderChipLabel(
                icon: recordingMode == 0 ? "hand.tap.fill" : "repeat.1",
                text: recordingMode == 0 ? "Hold" : "Toggle")
        }
        .menuIndicator(.hidden)
        .menuStyle(.borderlessButton)
        .tint(.white.opacity(0.9))
        .fixedSize()
        .help("Recording mode")
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    // MARK: - Live waveform
    // Samples come from AudioRecordingService.liveWaveSamples (peak amplitude per
    // audio buffer while recording). Rendered with a SwiftUI Canvas so it redraws
    // on every sample change.
    private static let waveBarWidth: CGFloat = 2.5
    private static let waveBarSpacing: CGFloat = 2.0

    // Default Init for Preview
    init(onCommit: ((String) -> Void)? = nil, onCancel: (() -> Void)? = nil) {
        self.onCommit = onCommit
        self.onCancel = onCancel
    }

    // MARK: - Display phase & pill geometry

    /// The recorder is always on screen. `idle` is the tiny resting pill; the
    /// other phases are the expanded HUD it morphs into.
    private enum RecorderPhase { case idle, warming, processing, recording }

    private var displayPhase: RecorderPhase {
        // Deliberately *not* `transcription.isLoading`: that is also true for a
        // background warm-up (after a download, or at launch), and the HUD must
        // never expand for work the user didn't ask for. `isWarmingUp` is set
        // only by this recorder's own load paths.
        if isWarmingUp { return .warming }
        if isProcessing { return .processing }
        if isListening { return .recording }
        return .idle
    }

    /// Width of the pill for the current phase. The frosted capsule animates
    /// between these, morphing the resting handle into the full HUD.
    private var pillWidth: CGFloat {
        switch displayPhase {
        case .idle: return 58
        case .warming: return 320
        case .processing: return 210
        case .recording: return expanded ? 460 : 250
        }
    }

    private var pillHeight: CGFloat {
        displayPhase == .idle ? 24 : 44
    }

    private var pillCornerRadius: CGFloat { pillHeight / 2 }

    // MARK: - Phase content

    /// Resting state — a small white waveform silhouette that sits perfectly
    /// still. Calm, minimal, premium: the same quiet rest at first launch and
    /// after a recording, with no idle "breathing" motion.
    private var idleContent: some View {
        HStack(spacing: 3) {
            ForEach(Array(Self.idleBarScale.enumerated()), id: \.offset) { _, scale in
                Capsule(style: .continuous)
                    .fill(Color.white)
                    .frame(width: 2.5, height: 12 * scale)
            }
        }
        .frame(height: 24)
        // Adapt to whatever shows through the glass: a difference blend renders the
        // bars subtly dark over a light backdrop and light over a dark one, so they
        // never just blend into white. Softened so it reads gentle, not harsh.
        .blendMode(.difference)
        .opacity(0.85)
        .transition(.opacity.combined(with: .scale(scale: 0.6)))
    }

    /// What the pill says while a model loads.
    ///
    /// The engine publishes a real stage ("Loading Parakeet model…"); fall back
    /// to a generic line only before the first stage arrives. Kept short on
    /// purpose — this sits in a fixed-width capsule, and the previous copy
    /// ("Warming up model — first use is slower…") was simply clipped mid-word.
    private var warmUpLabel: String {
        let stage = transcription.loadingStage
        return stage.isEmpty ? "Getting model ready…" : stage
    }

    private var warmingContent: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
                .colorScheme(.dark)

            VStack(alignment: .leading, spacing: 1) {
                Text(warmUpLabel)
                    .font(Typography.pillLabel)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                    .truncationMode(.tail)

                // A silent spinner gives no sense of how long this will take, so
                // once it stops feeling instant, say how long it has been and
                // that it only happens once.
                if warmUpElapsed >= 3 {
                    Text(warmUpElapsed >= 25
                         ? "\(Int(warmUpElapsed))s · almost there, first load only"
                         : "\(Int(warmUpElapsed))s · first load only")
                        .font(Typography.pillLabel)
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Text("esc")
                .font(Typography.pillLabel)
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.horizontal, 4)
        .transition(.opacity)
    }

    private var processingContent: some View {
        Text(statusMessage)
            .font(Typography.pillLabel)
            .foregroundColor(.white)
            .lineLimit(1)
            .transition(.opacity)
    }

    private var recordingContent: some View {
        HStack(spacing: 10) {
            recordingDot

            // Waveform — live render of the actual microphone input.
            // Calm/flat when silent, peaks on speech.
            Canvas { context, size in
                let raw = audioRecorder.liveWaveSamples
                guard !raw.isEmpty else { return }
                let step = Self.waveBarWidth + Self.waveBarSpacing
                let maxBars = max(1, Int(size.width / step))
                // Samples are raw linear peak amplitude (0...1), which sits LOW on
                // the scale — so we auto-gain to your own recent peak, meaning your
                // voice always fills the bars no matter the mic level. Two knobs:
                //   noiseGate  – trim dead-silence hiss before measuring.
                //   presence   – fade the whole waveform toward flat when the loudest
                //                thing in view is only faint ambient sound (a fan).
                //                It reaches full quickly, so real speech is never
                //                dimmed — only near-silence collapses. Raise
                //                `presenceFull` if the fan still shows; lower it if
                //                quiet speech looks weak.
                let noiseGate: Float = 0.02
                let presenceFull: Float = 0.08
                let gated = raw.suffix(maxBars).map { max(0, $0 - noiseGate) }
                let peak = gated.max() ?? 0
                let recentPeak = max(peak, 0.05)
                let presence = CGFloat(min(1, peak / presenceFull))
                let midY = size.height / 2
                for (i, sample) in gated.enumerated() {
                    let norm = CGFloat(min(1, sample / recentPeak)) * presence
                    let barHeight = max(2.0, norm * size.height)
                    let x = CGFloat(i) * step
                    let rect = CGRect(
                        x: x, y: midY - barHeight / 2,
                        width: Self.waveBarWidth, height: barHeight)
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: Self.waveBarWidth / 2),
                        with: .color(.white.opacity(0.9)))
                }
            }
            .frame(height: 22)
            .frame(maxWidth: .infinity)

            // Elapsed recording time.
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                Text(elapsedString(context.date))
                    .font(Typography.pillTime)
                    .foregroundColor(.white.opacity(0.6))
            }

            // Mic + mode + language: revealed inline on hover only, to keep
            // the resting state minimal.
            if expanded {
                micControl
                modeControl
                languageControl
            }
        }
        .padding(.horizontal, 14)
        .transition(.opacity)
    }

    /// Silhouette for the idle waveform — a soft, symmetric shape.
    private static let idleBarScale: [CGFloat] = [0.5, 0.85, 1.0, 0.85, 0.5]

    /// The morphing pill itself, sized to the current phase.
    private var pillView: some View {
        ZStack {
            backgroundView(cornerRadius: pillCornerRadius)

            switch displayPhase {
            case .warming:
                warmingContent
            case .processing:
                processingContent
            case .recording:
                recordingContent
            case .idle:
                idleContent
            }
        }
        .frame(width: pillWidth, height: pillHeight)
        .clipShape(RoundedRectangle(cornerRadius: pillCornerRadius, style: .continuous))
        .shadow(
            color: .black.opacity(displayPhase == .idle ? 0.35 : 0.45),
            radius: displayPhase == .idle ? 8 : 14,
            x: 0,
            y: displayPhase == .idle ? 3 : 5)
        .animation(.spring(response: 0.45, dampingFraction: 0.90), value: displayPhase)
        .animation(.spring(response: 0.40, dampingFraction: 0.92), value: expanded)
        .onHover { hovering in
            guard displayPhase == .recording else { return }
            expanded = hovering
        }
        .contextMenu {
            modelSelectionMenu
        }
    }

    var body: some View {
        // Fixed-size window; the pill is centered inside and morphs entirely in
        // SwiftUI. Because the window never resizes, the animation stays smooth
        // with no boundary clipping. Color.clear makes the root fill the window so
        // the pill is reliably centered.
        ZStack {
            Color.clear.allowsHitTesting(false)
            pillView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(NotificationCenter.default.publisher(for: .recordingStartRequested)) { _ in
            startRecording()
        }
        .onReceive(NotificationCenter.default.publisher(for: .recordingStopRequested)) { _ in
            stopAndTranscribe()
        }
        .onReceive(NotificationCenter.default.publisher(for: .recordingCancelRequested)) { _ in
            cancelRecording()
        }
        .onAppear {
            initializedService()
            audioRecorder.fetchAvailableDevices()

            // Set up Escape key monitors
            globalEscapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 {
                    Task { @MainActor in self.handleEscape() }
                }
            }
            localEscapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 {
                    Task { @MainActor in self.handleEscape() }
                    return nil  // swallow Escape
                }
                return event
            }
        }
        .onDisappear {
            if let globalEscapeMonitor = globalEscapeMonitor {
                NSEvent.removeMonitor(globalEscapeMonitor)
            }
            if let localEscapeMonitor = localEscapeMonitor {
                NSEvent.removeMonitor(localEscapeMonitor)
            }
            audioRecorder.stopSessionIfIdle()
        }
        .onChange(of: isListening) {
            // Only animate when actually recording to save CPU
            if isListening {
                recordingStart = Date()
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    phase = .pi * 4
                }
                withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                    dotPulse = true
                }
            } else {
                recordingStart = nil
                phase = 0
                dotPulse = false
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        ) { _ in
            // Ensure focus if needed
        }
        .background(
            KeyEventHandlerView(onEscape: {
                handleEscape()
            })
        )
        .alert("Accessibility Permission Required", isPresented: $showAccessibilityWarning) {
            Button("Open Settings") {
                if let url = URL(
                    string:
                        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                ) {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Continue Anyway", role: .cancel) {}
        } message: {
            Text(
                "Accessibility is disabled. Transcribed text will be copied to clipboard but won't auto-paste into apps.\n\nEnable it in System Settings → Privacy & Security → Accessibility."
            )
        }
    }

    // MARK: - Subviews

    /// Live recording indicator — a soft, pulsing red dot. Reads as "recording",
    /// not a button. Still tappable to stop for users who prefer clicking.
    private var recordingDot: some View {
        let core = Color(red: 1.0, green: 0.27, blue: 0.24)
        return Circle()
            .fill(core)
            .frame(width: 10, height: 10)
            .overlay(
                Circle()
                    .stroke(core.opacity(0.35), lineWidth: 5)
                    .scaleEffect(dotPulse ? 2.1 : 1.0)
                    .opacity(dotPulse ? 0 : 0.9)
            )
            .shadow(color: core.opacity(0.6), radius: 4, x: 0, y: 0)
            .frame(width: 24, height: 24)  // stable hit + halo area
            .contentShape(Circle())
            .onTapGesture { handleHotkeyTrigger() }
            .help("Recording — click or press your hotkey to stop")
    }

    @ViewBuilder
    private func backgroundView(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if displayPhase == .idle {
            if pillIsDark {
                // Dark mode: a near-black premium pill rendered PURELY in SwiftUI.
                // We deliberately avoid a behind-window NSVisualEffectView here: as
                // a freshly-inserted AppKit view it crossfades its material in on
                // the light→dark switch (under the system's appearance-transition),
                // so the pill took ~a second to darken while dark→light (SwiftUI
                // glass) was instant. An opaque SwiftUI fill flips with `colorScheme`
                // immediately in both directions. This mirrors the active-HUD look
                // below (`Color(white: 0.05)`), plus a faint top sheen for edge
                // definition. We also skip Liquid Glass in dark: its material paints
                // a luminous edge that reads as a white frost ring no matter the tint.
                ZStack {
                    shape.fill(Color(white: 0.06))
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.09),
                                Color.white.opacity(0.01),
                            ],
                            startPoint: .top,
                            endPoint: .bottom),
                        lineWidth: 0.75)
                }
            } else if #available(macOS 26.0, *) {
                // Light mode: native Liquid Glass — frosted, refractive, gorgeous.
                Color.clear
                    .glassEffect(.regular, in: shape)
                    .overlay {
                        // Soft frost hugging the inside edge; clear center.
                        ZStack {
                            shape
                                .stroke(Color.white.opacity(0.14), lineWidth: 6)
                                .blur(radius: 4)
                            shape.strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.35),
                                        Color.white.opacity(0.06),
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom),
                                lineWidth: 1)
                        }
                        .clipShape(shape)
                    }
            } else {
                // Light mode on macOS 14–15 (no Liquid Glass): behind-window blur.
                ZStack {
                    VisualEffectBlur(
                        material: .hudWindow,
                        blendingMode: .behindWindow,
                        cornerRadius: cornerRadius)
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.55),
                                Color.white.opacity(0.08),
                            ],
                            startPoint: .top,
                            endPoint: .bottom),
                        lineWidth: 1)
                }
            }
        } else {
            // Active HUD: deep, opaque near-black so warming/recording/processing
            // text stays fully legible over any backdrop.
            ZStack {
                shape.fill(Color(white: 0.05))
                shape.strokeBorder(Color.white.opacity(0.10), lineWidth: 0.8)
            }
        }
    }

    @ViewBuilder
    private var modelSelectionMenu: some View {
        ForEach(AIModel.availableModels) { model in
            Button {
                let previousModel = selectedModel
                selectedModel = model.variant

                // Pre-load the new model immediately so the first transcription isn't slow
                if model.variant != previousModel {
                    Task {
                        await MainActor.run { beginWarmUp() }
                        do {
                            try await transcription.loadModel(variant: model.variant)
                            debugLog("Model pre-loaded after switch: \(model.variant)")
                        } catch {
                            debugLog("Model pre-load failed: \(error.localizedDescription)")
                        }
                        await MainActor.run { endWarmUp() }
                    }
                }
            } label: {
                if selectedModel == model.variant {
                    Label(model.name, systemImage: "checkmark")
                } else {
                    Text(model.name)
                }
            }
        }
    }

    // MARK: - Logic

    private func initializedService() {
        // NOTE: the recorder is now always on screen, so we must NOT keep the mic
        // capture session warm here — that would light the system mic indicator at
        // all times. The session is started on demand when recording begins.

        guard !selectedModel.isEmpty else {
            debugLog("No model selected - skipping initialization")
            return
        }

        Task {
            debugLog("Initializing WhisperService with model: \(selectedModel)")
            do {
                try await transcription.loadModel(variant: selectedModel)
                debugLog("Model preloaded successfully")
            } catch {
                debugLog("Model preload failed: \(error.localizedDescription)")
            }
        }
    }

    private func handleHotkeyTrigger() {
        if isListening {
            stopAndTranscribe()
        } else {
            startRecording()
        }
    }

    private func cancelRecording() {
        cancelCommit = true

        guard isListening || audioRecorder.isRecording else {
            isProcessing = false
            onCancel?()
            return
        }

        Task {
            _ = await audioRecorder.stopRecording(discardOutput: true)

            await MainActor.run {
                isListening = false
                isProcessing = false
                statusMessage = "Transcribing..."
                onCancel?()
            }
        }
    }

    private func startRecording() {
        guard !isProcessing else {
            debugLog("Already processing, ignoring start request")
            return
        }

        guard !isListening else {
            debugLog("Already listening, ignoring duplicate start request")
            return
        }

        // Warn (at most once) if accessibility is off — transcribed text still lands
        // on the clipboard, we just can't auto-paste. Skipped entirely in DEBUG so
        // frequent rebuilds (which reset the TCC grant) don't nag while testing.
        #if !DEBUG
            if !isAccessibilityEnabled && !hasShownAccessibilityWarning {
                hasShownAccessibilityWarning = true
                showAccessibilityWarning = true
            }
        #endif

        // Check if model is selected BEFORE starting recording
        guard !selectedModel.isEmpty else {
            debugLog("No model selected - showing error")
            isProcessing = true
            statusMessage = "No model selected"

            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                isProcessing = false
                onCancel?()
            }
            return
        }

        // Check if model is downloaded
        let progress = ModelDownloadService.shared.downloadProgress[selectedModel] ?? 0
        guard progress >= 1.0 else {
            debugLog("Model not downloaded - showing error")
            isProcessing = true
            statusMessage = "Model not downloaded"

            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                isProcessing = false
                onCancel?()
            }
            return
        }

        cancelCommit = false

        debugLog("Starting recording...")
        audioRecorder.startRecording()
        isListening = true
    }

    private func selectAudioDevice(_ deviceId: String) {
        guard audioRecorder.selectedDeviceId != deviceId else { return }

        let shouldResumeRecording = isListening

        Task {
            if shouldResumeRecording {
                await MainActor.run {
                    isListening = false
                    isProcessing = true
                    statusMessage = "Switching input..."
                }

                _ = await audioRecorder.stopRecording(discardOutput: true)
            }

            await MainActor.run {
                audioRecorder.selectedDeviceId = deviceId
            }

            guard shouldResumeRecording else { return }

            audioRecorder.startRecording()

            await MainActor.run {
                isProcessing = false
                isListening = true
            }
        }
    }

    private func stopAndTranscribe() {
        debugLog("stopAndTranscribe called")

        guard isListening || audioRecorder.isRecording else {
            debugLog("Not listening, ignoring duplicate stop request")
            return
        }

        // Check if model is selected
        guard !selectedModel.isEmpty else {
            debugLog("No model selected - cannot transcribe")
            Task { @MainActor in
                isListening = false
                isProcessing = false
                statusMessage = "No AI model selected. Go to Settings → AI Models to download one."

                // Show error for 3 seconds
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                onCancel?()
            }
            return
        }

        Task {
            let url = await audioRecorder.stopRecording()
            debugLog("stopRecording returned: \(url?.absoluteString ?? "nil")")

            guard let url = url else {
                debugLog("No recording URL, cancelling")
                await MainActor.run {
                    isListening = false
                    onCancel?()
                }
                return
            }

            await MainActor.run {
                isListening = false
                isProcessing = true
                statusMessage = "Transcribing..."
            }

            // Always use the final full-recording transcription for committed output.
            // Chunk stitching caused repeated phrases at boundaries across languages.
            await processRecording(url: url)
        }
    }

    /// Enter the warming phase and start counting seconds.
    private func beginWarmUp() {
        isWarmingUp = true
        warmUpStart = Date()
        warmUpElapsed = 0
        warmUpTimer?.invalidate()
        warmUpTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let start = warmUpStart { warmUpElapsed = Date().timeIntervalSince(start) }
        }
    }

    /// Leave the warming phase. Safe to call when not warming.
    private func endWarmUp() {
        warmUpTimer?.invalidate()
        warmUpTimer = nil
        warmUpStart = nil
        warmUpElapsed = 0
        isWarmingUp = false
    }

    private func handleEscape() {
        guard isListening || isProcessing || isWarmingUp else { return }

        debugLog("Escape pressed - cancelling immediate commit")
        cancelCommit = true

        if isListening {
            Task {
                let url = await audioRecorder.stopRecording()

                await MainActor.run {
                    isListening = false
                    isProcessing = true
                    statusMessage = "Stopping transcription..."
                }

                if let url = url {
                    // Let it process in the background and save to history, but don't commit to UI
                    await processRecording(url: url)
                } else {
                    await MainActor.run {
                        onCancel?()
                    }
                }
            }
        } else {
            // Already warming up or processing. Clearing both flags is what
            // actually returns the pill to idle: `onCancel` only tells the
            // window to settle, so leaving `isProcessing` set left the HUD
            // wedged open — the status text stayed on screen with no way to
            // dismiss it. The load itself keeps running in the background and
            // will simply be ready for the next dictation.
            statusMessage = isWarmingUp ? "Continuing in background..." : "Stopping transcription..."
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self.endWarmUp()
                self.isProcessing = false
                self.onCancel?()
            }
        }
    }

    private func debugLog(_ message: String) {
        let logPath = "/tmp/speaktype_debug.log"
        let logEntry = "[\(Date())] \(message)\n"
        if let data = logEntry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logPath) {
                if let handle = FileHandle(forWritingAtPath: logPath) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                FileManager.default.createFile(atPath: logPath, contents: data)
            }
        }
    }

    private func processRecording(url: URL) async {
        debugLog("processRecording started with url: \(url.lastPathComponent)")
        do {
            // Ensure model is loaded before transcribing
            if !transcription.isInitialized || transcription.currentModelVariant != selectedModel
            {
                debugLog("Loading model: \(selectedModel)")
                // Show the dedicated warming phase (spinner + live stage +
                // elapsed) rather than a long sentence stuffed into the
                // fixed-width processing pill, where it was clipped mid-word.
                await MainActor.run { beginWarmUp() }
                do {
                    try await transcription.loadModel(variant: selectedModel)
                    debugLog("Model loaded successfully")
                    await MainActor.run { endWarmUp() }
                } catch {
                    debugLog("Model load failed: \(error.localizedDescription)")
                    await MainActor.run {
                        endWarmUp()
                        statusMessage = "Model load failed"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            self.isProcessing = false
                            self.onCancel?()
                        }
                    }
                    return
                }
            }

            debugLog("Starting transcription...")
            // If user has already cancelled (pressed Escape), skip transcription UI updates
            // but still run the transcription in the background to save to history
            if !cancelCommit {
                await MainActor.run { statusMessage = "Transcribing..." }
            }
            let text = try await transcription.transcribe(audioFile: url, language: transcriptionLanguage)
            debugLog("Transcription result: \(text.prefix(50))...")

            guard !text.isEmpty else {
                debugLog("Empty text, cancelling")
                await MainActor.run {
                    statusMessage = "No speech detected"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.isProcessing = false
                        self.onCancel?()
                    }
                }
                return
            }

            let duration = await getAudioDuration(url: url)
            let modelName =
                AIModel.availableModels.first(where: { $0.variant == selectedModel })?.name
                ?? selectedModel
            HistoryService.shared.addItem(
                transcript: text,
                duration: duration,
                audioFileURL: url,
                modelUsed: modelName,
                transcriptionTime: nil
            )

            debugLog("Calling onCommit...")
            await MainActor.run {
                if !cancelCommit {
                    onCommit?(text)
                }
                isProcessing = false

                // If we cancelled by dismissing early, the window might already be closed,
                // but if we waited for it (e.g. short transcription), close it now.
                if cancelCommit {
                    onCancel?()
                }
            }
            debugLog("onCommit called successfully")
        } catch {
            debugLog("Error: \(error.localizedDescription)")
            await MainActor.run {
                statusMessage = "Transcription failed"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.isProcessing = false
                    self.onCancel?()
                }
            }
        }
    }

    private func getAudioDuration(url: URL) async -> TimeInterval {
        let asset = AVURLAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            return CMTimeGetSeconds(duration)
        } catch {
            return 0
        }
    }

    private func spokenLanguageDisplayName(for code: String) -> String {
        if code == "auto" { return "Auto-detect" }
        return GeneralSettingsTab.whisperLanguages.first(where: { $0.code == code })?.name ?? code
    }
}

// MARK: - Helper Shapes & Views

struct ChevronShape: Shape {
    let pointsUp: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()

        if pointsUp {
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }

        return path
    }
}

struct DoubleChevronIcon: View {
    let color: Color

    var body: some View {
        VStack(spacing: 1) {
            ChevronShape(pointsUp: true)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 1.35, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 7, height: 4)

            ChevronShape(pointsUp: false)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 1.35, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 7, height: 4)
        }
        .frame(width: 8, height: 10)
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var cornerRadius: CGFloat = 0
    /// Force a fixed vibrancy appearance (e.g. `.vibrantDark`) so the frosted
    /// glass stays dark/premium regardless of the system light/dark setting.
    var appearanceName: NSAppearance.Name? = nil

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active

        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = cornerRadius
        visualEffectView.layer?.masksToBounds = true

        if let appearanceName {
            visualEffectView.appearance = NSAppearance(named: appearanceName)
        }

        return visualEffectView
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.layer?.cornerRadius = cornerRadius
        if let appearanceName {
            nsView.appearance = NSAppearance(named: appearanceName)
        }
    }
}

// MARK: - Key Event Handler

struct KeyEventHandlerView: NSViewRepresentable {
    let onEscape: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = KeyCaptureView()
        view.onEscape = onEscape
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? KeyCaptureView {
            view.onEscape = onEscape
            DispatchQueue.main.async {
                view.window?.makeFirstResponder(view)
            }
        }
    }

    class KeyCaptureView: NSView {
        var onEscape: (() -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.window?.makeFirstResponder(self)
            }
        }

        override func keyDown(with event: NSEvent) {
            if event.keyCode == 53 {  // Escape key
                onEscape?()
            } else {
                super.keyDown(with: event)
            }
        }
    }
}
