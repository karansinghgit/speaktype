import SwiftUI
import Combine
import AVFoundation
import CoreMedia

struct MiniRecorderView: View {
    @ObservedObject private var audioRecorder = AudioRecordingService.shared
    @State private var whisperService = WhisperService()
    @State private var isListening = false
    @State private var isProcessing = false
    var onCommit: ((String) -> Void)?
    var onCancel: (() -> Void)?
    
    @AppStorage("selectedModelVariant") private var selectedModel: String = "openai_whisper-base.en"
    
    // MARK: - State for Animation
    @State private var phase: CGFloat = 0
    
    // Smooth out the raw audio level for cleaner wave height
    private var normalizedAudioLevel: CGFloat {
        let level = CGFloat(audioRecorder.audioLevel)
        // Reduced amplitude multiplier for smoother, less harsh waves
        return max(2.0, sqrt(level) * 20.0) 
    }
    
    // Map normalized frequency (0-1) to a visual frequency range
    private var targetFrequency: CGFloat {
        let baseFreq: CGFloat = 8.0
        let range: CGFloat = 10.0 // Reduced range for less erratic movement
        return baseFreq + (CGFloat(audioRecorder.audioFrequency) * range)
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
                Text("Transcribing...")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .transition(.opacity)
            } else {
                HStack(spacing: 12) {
                    stopButton
                    
                    // Waveform Container
                    ZStack {
                        // Multiple waves for "water-like" effect
                        HorizontalWave(
                            phase: phase,
                            amplitude: normalizedAudioLevel,
                            frequency: targetFrequency
                        )
                        .stroke(
                            LinearGradient(
                                colors: [.cyan.opacity(0.5), .blue.opacity(0.5)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 2
                        )
                        .offset(y: 1)

                        HorizontalWave(
                            phase: phase * 1.5 + 2,
                            amplitude: normalizedAudioLevel * 0.8,
                            frequency: targetFrequency * 1.2
                        )
                        .stroke(
                            LinearGradient(
                                colors: [.green, .yellow, .orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 3
                        )
                        // Slower animation response for smoother look
                        .animation(.linear(duration: 0.2), value: audioRecorder.audioFrequency)
                        .animation(.linear(duration: 0.2), value: audioRecorder.audioLevel)
                    }
                    .frame(height: 30) // Compact waveform height
                    .clipShape(RoundedRectangle(cornerRadius: 6))
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
            // Slower, calmer phase animation
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
             // Ensure focus if needed
        }
    }
    
    // MARK: - Subviews
    
    private var stopButton: some View {
        Button(action: {
            handleHotkeyTrigger()
        }) {
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
        }
        .buttonStyle(.plain)
    }
    
    private var backgroundView: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).opacity(0.8) // Native semi-transparent look
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow, cornerRadius: 25) // Glass effect
            Color.black.opacity(0.8) // Dark tin
            
            // Subtle border
            RoundedRectangle(cornerRadius: 25)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.15), .white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
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
        Task {
            try? await whisperService.loadModel(variant: selectedModel)
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
        guard !isProcessing else { return }
        audioRecorder.startRecording()
        isListening = true
    }
    
    private func stopAndTranscribe() {
        Task {
            guard let url = await audioRecorder.stopRecording() else {
                await MainActor.run { isListening = false }
                return
            }
            
            await MainActor.run {
                isListening = false
                isProcessing = true
            }
            
            await processRecording(url: url)
        }
    }

    private func processRecording(url: URL) async {
        do {
             if !whisperService.isInitialized || whisperService.currentModelVariant != selectedModel {
                 try? await whisperService.loadModel(variant: selectedModel)
             }
             
             let text = try await whisperService.transcribe(audioFile: url)
             
             guard !text.isEmpty else {
                 await MainActor.run { isProcessing = false }
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
             
             await MainActor.run {
                 onCommit?(text)
                 isProcessing = false
             }
        } catch {
             await MainActor.run { isProcessing = false }
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
