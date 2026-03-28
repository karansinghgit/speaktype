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
    @State private var showAccessibilityWarning = false
    var onCommit: ((String) -> Void)?
    var onCancel: (() -> Void)?

    @AppStorage(ModelSelection.defaultsKey) private var selectedModel: String = ModelSelection.none
    @AppStorage("recordingMode") private var recordingMode: Int = 0
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

    // MARK: - State for Animation
    @State private var phase: CGFloat = 0

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

    var body: some View {
        ZStack {
            backgroundView

            if isWarmingUp || transcription.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                        .colorScheme(.dark)
                    Text("Warming up model...")
                        .font(Typography.labelMedium)
                        .foregroundColor(.white.opacity(0.9))
                }
                .transition(.opacity)
            } else if isProcessing {
                Text(statusMessage)
                    .font(Typography.labelMedium)
                    .foregroundColor(.white)
                    .transition(.opacity)
            } else {
                HStack(spacing: 12) {
                    stopButton

                    // Waveform — live render of the actual microphone input.
                    // Calm/flat when silent, peaks on speech.
                    Canvas { context, size in
                        let raw = audioRecorder.liveWaveSamples
                        guard !raw.isEmpty else { return }
                        let step = Self.waveBarWidth + Self.waveBarSpacing
                        let maxBars = max(1, Int(size.width / step))
                        // Noise-gate, then auto-gain to the recent peak so the
                        // waveform stays lively and well-scaled at any volume.
                        let visible = raw.suffix(maxBars).map { max(0, $0 - 0.02) }
                        let recentPeak = max(visible.max() ?? 0, 0.05)
                        let midY = size.height / 2
                        for (i, sample) in visible.enumerated() {
                            let norm = CGFloat(min(1, sample / recentPeak))
                            let barHeight = max(2.5, norm * size.height)
                            let x = CGFloat(i) * step
                            let rect = CGRect(
                                x: x, y: midY - barHeight / 2,
                                width: Self.waveBarWidth, height: barHeight)
                            context.fill(
                                Path(roundedRect: rect, cornerRadius: Self.waveBarWidth / 2),
                                with: .color(.white.opacity(0.9)))
                        }
                    }
                    .frame(width: 96, height: 26)

                    HStack(spacing: 8) {
                        Menu {
                            Button("Auto-detect") { setLanguage("auto") }

                            if !quickLanguageCodes.isEmpty {
                                Divider()
                                ForEach(quickLanguageCodes, id: \.self) { code in
                                    if let lang = GeneralSettingsTab.whisperLanguages.first(where: {
                                        $0.code == code
                                    }) {
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
                            HStack(spacing: 6) {
                                Text(currentLanguageLabel)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.92))
                                    .lineLimit(1)
                                    .truncationMode(.tail)

                                DoubleChevronIcon(color: .white.opacity(0.92))
                            }
                            .frame(maxWidth: 74, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .menuIndicator(.hidden)
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        .help(spokenLanguageHelpText)

                        Menu {
                            if audioRecorder.availableDevices.isEmpty {
                                Button("No input devices found") {}
                                    .disabled(true)
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
                            Button("Refresh inputs") {
                                audioRecorder.fetchAvailableDevices()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.92))

                                DoubleChevronIcon(color: .white.opacity(0.92))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .menuIndicator(.hidden)
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        .help(inputDeviceHelpText)

                        // Recording mode indicator
                        Image(systemName: recordingMode == 0 ? "hand.tap.fill" : "repeat.1")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .help(recordingMode == 0 ? "Hold to Record" : "Toggle to Record")
                    }
                }
                .padding(.horizontal, 12)
                .transition(.opacity)
            }
        }
        .frame(width: 260, height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 25))
        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 2)
        .contextMenu {
            modelSelectionMenu
        }
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
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    phase = .pi * 4
                }
            } else {
                phase = 0
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

    private var stopButton: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)  // Squircle
                .fill(Color(red: 1.0, green: 0.2, blue: 0.2))  // Bright Red
                .frame(width: 32, height: 32)  // Smaller button
                .shadow(color: Color.red.opacity(0.4), radius: 4, x: 0, y: 0)

            // Inner square icon
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.black.opacity(0.4))
                .frame(width: 10, height: 10)
        }
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture {
            handleHotkeyTrigger()
        }
    }

    private var backgroundView: some View {
        ZStack {
            // Dark background with blur, all clipped to capsule
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow, cornerRadius: 25)
                .clipShape(RoundedRectangle(cornerRadius: 25))

            RoundedRectangle(cornerRadius: 25)
                .fill(Color.black.opacity(0.85))

            // Subtle border
            RoundedRectangle(cornerRadius: 25)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
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
                        await MainActor.run { isWarmingUp = true }
                        do {
                            try await transcription.loadModel(variant: model.variant)
                            debugLog("Model pre-loaded after switch: \(model.variant)")
                        } catch {
                            debugLog("Model pre-load failed: \(error.localizedDescription)")
                        }
                        await MainActor.run { isWarmingUp = false }
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
        // Pre-warm the audio capture session for instant first recording
        audioRecorder.prewarmSession()

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

        // Check if accessibility is enabled - warn but don't block
        if !isAccessibilityEnabled {
            showAccessibilityWarning = true
        }

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

    private func handleEscape() {
        guard isListening || isProcessing || isWarmingUp || transcription.isLoading else { return }

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
            // Already processing, just show stopping and quickly dismiss
            statusMessage = "Stopping transcription..."
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                onCancel?()
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
                await MainActor.run { statusMessage = "Warming up model — first use is slower..." }
                do {
                    try await transcription.loadModel(variant: selectedModel)
                    debugLog("Model loaded successfully")
                } catch {
                    debugLog("Model load failed: \(error.localizedDescription)")
                    await MainActor.run {
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

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active

        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = cornerRadius
        visualEffectView.layer?.masksToBounds = true

        return visualEffectView
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.layer?.cornerRadius = cornerRadius
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
