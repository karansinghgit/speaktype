import SwiftUI
import Combine
import AVFoundation
import CoreMedia

struct MiniRecorderView: View {
    @ObservedObject private var audioRecorder = AudioRecordingService.shared
    private var whisperService: WhisperService { WhisperService.shared }
    @State private var isListening = false

    @State private var isProcessing = false
    @State private var statusMessage = "Transcribing..."
    @State private var showAccessibilityWarning = false
    var onCommit: ((String) -> Void)?
    var onCancel: (() -> Void)?
    
    @AppStorage("selectedModelVariant") private var selectedModel: String = ""
    
    private var isAccessibilityEnabled: Bool {
        AXIsProcessTrusted()
    }
    
    // MARK: - State for Animation
    @State private var phase: CGFloat = 0
    
    // Calculate bar height based on audio level and position
    private func barHeight(for index: Int) -> CGFloat {
        let level = CGFloat(audioRecorder.audioLevel)
        let baseHeight: CGFloat = 4
        let maxHeight: CGFloat = 28
        
        // Create wave pattern that responds to audio
        let waveOffset = sin(CGFloat(index) * 0.5 + phase) * 0.3
        let audioMultiplier = sqrt(level) * (0.8 + waveOffset)
        
        let height = baseHeight + (maxHeight - baseHeight) * audioMultiplier
        return max(baseHeight, min(height, maxHeight))
    }
    
    // Default Init for Preview
    init(onCommit: ((String) -> Void)? = nil, onCancel: (() -> Void)? = nil) {
        self.onCommit = onCommit
        self.onCancel = onCancel
    }
    
    var body: some View {
        ZStack {
            backgroundView
            
            if isProcessing {
                Text(statusMessage)
                    .font(Typography.labelMedium)
                    .foregroundColor(.white)
                    .transition(.opacity)
            } else {
                HStack(spacing: 12) {
                    stopButton
                    
                    // Waveform - bar visualizer style
                    HStack(spacing: 3) {
                        ForEach(0..<20) { index in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.7))
                                .frame(width: 3, height: barHeight(for: index))
                                .animation(.easeInOut(duration: 0.15), value: audioRecorder.audioLevel)
                        }
                    }
                    .frame(height: 30)
                }
                .padding(.horizontal, 12)
                .transition(.opacity)
            }
        }
        .frame(width: 220, height: 50) // Reduced overall size
        .clipShape(RoundedRectangle(cornerRadius: 25))
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
        .contextMenu {
            modelSelectionMenu
        }
        .onReceive(NotificationCenter.default.publisher(for: .recordingStartRequested)) { _ in
            startRecording()
        }
        .onReceive(NotificationCenter.default.publisher(for: .recordingStopRequested)) { _ in
            stopAndTranscribe()
        }
        .onAppear {
            initializedService()
        }
        .onChange(of: isListening) { listening in
            // Only animate when actually recording to save CPU
            if listening {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    phase = .pi * 4
                }
            } else {
                phase = 0
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
             // Ensure focus if needed
        }
        .background(
            KeyEventHandlerView(onEscape: {
                if isListening {
                    stopAndTranscribe()
                }
            })
        )
        .alert("Accessibility Permission Required", isPresented: $showAccessibilityWarning) {
            Button("Open Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Continue Anyway", role: .cancel) { }
        } message: {
            Text("Accessibility is disabled. Transcribed text will be copied to clipboard but won't auto-paste into apps.\n\nEnable it in System Settings → Privacy & Security → Accessibility.")
        }
    }
    
    // MARK: - Subviews
    
    private var stopButton: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10) // Squircle
                .fill(Color(red: 1.0, green: 0.2, blue: 0.2)) // Bright Red
                .frame(width: 32, height: 32) // Smaller button
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
            // Dark background with blur
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow, cornerRadius: 25)
            Color.black.opacity(0.85)
            
            // Subtle border
            RoundedRectangle(cornerRadius: 25)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        }
    }
    
    @ViewBuilder
    private var modelSelectionMenu: some View {
        ForEach(AIModel.availableModels) { model in
            Button {
                selectedModel = model.variant
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
                try await whisperService.loadModel(variant: selectedModel)
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
    
    private func startRecording() {
        guard !isProcessing else {
            debugLog("Already processing, ignoring start request")
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
        
        debugLog("Starting recording...")
        audioRecorder.startRecording()
        isListening = true
    }
    
    private func stopAndTranscribe() {
        debugLog("stopAndTranscribe called")
        
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
            
            await processRecording(url: url)
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
             if !whisperService.isInitialized || whisperService.currentModelVariant != selectedModel {
                 debugLog("Loading model: \(selectedModel)")
                 await MainActor.run { statusMessage = "Loading AI model (one-time)..." }
                 do {
                     try await whisperService.loadModel(variant: selectedModel)
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
             await MainActor.run { statusMessage = "Transcribing..." }
             let text = try await whisperService.transcribe(audioFile: url)
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
             let modelName = AIModel.availableModels.first(where: { $0.variant == selectedModel })?.name ?? selectedModel
             HistoryService.shared.addItem(
                transcript: text,
                duration: duration,
                audioFileURL: url,
                modelUsed: modelName,
                transcriptionTime: nil
             )
             
             debugLog("Calling onCommit...")
             await MainActor.run {
                 onCommit?(text)
                 isProcessing = false
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
}

// MARK: - Helper Shapes & Views

struct HorizontalWave: Shape {
    var phase: CGFloat
    var amplitude: CGFloat
    var frequency: CGFloat
    
    // Allow animation of phase, amplitude, AND frequency
    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(phase, AnimatablePair(amplitude, frequency)) }
        set {
            phase = newValue.first
            amplitude = newValue.second.first
            frequency = newValue.second.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midHeight = height / 2
        
        // Start at left middle
        path.move(to: CGPoint(x: 0, y: midHeight))
        
        for x in stride(from: 0, through: width, by: 1) {
            let relativeX = x / width
            
            // Sine wave formula: y = A * sin(kx - wt)
            // k = 2pi * frequency (cycles across width)
            // wt = phase
            let sine = sin((relativeX * .pi * 2 * frequency) - phase)
            
            let y = midHeight + sine * amplitude
            
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        return path
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
        }
    }
    
    class KeyCaptureView: NSView {
        var onEscape: (() -> Void)?
        
        override var acceptsFirstResponder: Bool { true }
        
        override func keyDown(with event: NSEvent) {
            if event.keyCode == 53 { // Escape key
                onEscape?()
            } else {
                super.keyDown(with: event)
            }
        }
    }
}
